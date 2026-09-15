// Copyright (c) 2025 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import FileProvider
import Foundation
import CoreData
import ProtonCoreCryptoGoInterface
@preconcurrency import PDCore

/// Shared paging parameters for both change-enumeration paths (resync offset paging and the event loop).
enum ChangesPaging {
    /// Page size for delivering changes. Each page is a full enumerator round-trip, so the system hint is
    /// multiplied by 8 to cut round-trips (well under the framework's 100× suggested-size limit).
    /// No hint → 200.
    static func batchSize(for observers: [any NSFileProviderChangeObserver]) -> Int {
        guard let suggested = observers.compactMap({ $0.suggestedBatchSize }).filter({ $0 > 0 }).min() else {
            return 200
        }
        return suggested * 8
    }
}

public enum ChangesEnumerationMode: Int, RawRepresentable, CustomStringConvertible {
    case eventLoop = 0
    case userInitiatedRefresh = 1
    case fullResync = 2
    case recoveryResync = 3
    
    public static var `default`: Self = .eventLoop
    
    public var description: String {
        switch self {
        case .eventLoop: return ".eventLoop"
        case .userInitiatedRefresh: return ".userInitiatedRefresh"
        case .fullResync: return ".fullResync"
        case .recoveryResync: return ".recoveryResync"
        }
    }
}

public final class ResyncEnumerationService {
    
    public static let nodeIdentifiersTempFileName = "tmp_node_ids.lz4"
    /// Node-id snapshot written before a metadata wipe; a login-reconnection resync promotes it to the
    /// canonical file. Distinct name so other resyncs ignore it.
    public static let prewipeNodeIdentifiersTempFileName = "tmp_prewipe_node_ids.lz4"
    public static let nodeIdentifiersTempFileCompressionAlgorithm: NSData.CompressionAlgorithm = .lz4
    private static let numberOfNodesProcessedPerChildContext = 1500
    
    @NonOptionalSettingsStorage(UserDefaults.FileProvider.workingSetEnumerationInProgressKey.rawValue, defaultValue: false) public internal(set) var workingSetEnumerationInProgress: Bool
    @NonOptionalSettingsStorage(UserDefaults.FileProvider.fullResyncInProgressKey.rawValue, defaultValue: false) public private(set) var fullResyncInProgress: Bool
    @NonOptionalSettingsStorage(UserDefaults.FileProvider.cannotSynchronizeEarlyExitOccurredKey.rawValue, defaultValue: false) private var cannotSynchronizeEarlyExitOccurred: Bool
    /// Monotonic count of `.cannotSynchronize` early-exits, read by `FullResyncCoordinator.reenumerateAfterResyncing` to detect queue draining. All writes go through `resyncCounterQueue`.
    @NonOptionalSettingsStorage(UserDefaults.FileProvider.cannotSynchronizeEarlyExitCountKey.rawValue, defaultValue: 0) private var cannotSynchronizeEarlyExitCount: Int
    /// Monotonic count of items fetched during the post-resync fetch pass (each completed `item(for:)` bumps it), read by `FullResyncCoordinator.reenumerateAfterResyncing` for alias-free quiet detection and progress. All writes go through `resyncCounterQueue`.
    @NonOptionalSettingsStorage(UserDefaults.FileProvider.fetchedItemCountKey.rawValue, defaultValue: 0) private var fetchedItemCount: Int
    /// Monotonic count of changes pages delivered during a resync. `FullResyncCoordinator`'s Wait 1 restarts its per-page timeout whenever this advances. All writes go through `resyncCounterQueue`.
    @NonOptionalSettingsStorage(UserDefaults.FileProvider.resyncEnumerationPageCountKey.rawValue, defaultValue: 0) private var resyncEnumerationPageCount: Int
    @RawRepresentableSettingsStorage(UserDefaults.FileProvider.shouldReenumerateItemsKey.rawValue, defaultValue: ChangesEnumerationMode.eventLoop) public private(set) var changesEnumerationMode: ChangesEnumerationMode
    
    public var isForceRefreshing: Bool = false

    /// Test override for the update-decryption group size; nil uses the production value.
    var decryptionGroupSizeOverrideForTesting: Int?

    /// Reuses one computed diff across the stateless per-page calls of a resync run.
    let diffCache = ResyncDiff.Cache()

    private var resyncCounterQueue = DispatchQueue(
        label: "me.proton.drive.file-provider.resync-counter-queue", qos: .userInitiated
    )

    private let settingsStorage: SettingsStorageSuite

    public init(settingsStorage: SettingsStorageSuite) {
        self.settingsStorage = settingsStorage
        _workingSetEnumerationInProgress.configure(with: settingsStorage)
        _fullResyncInProgress.configure(with: settingsStorage)
        _cannotSynchronizeEarlyExitOccurred.configure(with: settingsStorage)
        _cannotSynchronizeEarlyExitCount.configure(with: settingsStorage)
        _fetchedItemCount.configure(with: settingsStorage)
        _resyncEnumerationPageCount.configure(with: settingsStorage)
        _changesEnumerationMode.configure(with: settingsStorage)
    }
    
    // MARK: - Fetch Item Pass Counter Management
    
    public func startUserInitiatedRefresh() {
        changesEnumerationMode = .userInitiatedRefresh
    }

    public func clearEnumerationMode() {
        changesEnumerationMode = .default
    }

    /// Records that an operation early-exited with `.cannotSynchronize` because a full resync was
    /// running. The app signals resolution of this error once the domain reconnects.
    public func recordCannotSynchronizeEarlyExit() {
        cannotSynchronizeEarlyExitOccurred = true
        // Bump the monotonic counter so the coordinator's quiet detection counts queue draining as activity.
        resyncCounterQueue.async { [weak self] in
            guard let self else { return }
            self.cannotSynchronizeEarlyExitCount += 1
        }
    }

    /// Records that an `item(for:)` fetch completed during the post-resync fetch pass. Monotonic, so the
    /// coordinator's quiet detection cannot be fooled by an oscillating counter; errored fetches still
    /// count because a completed-with-error fetch is still activity.
    public func recordFetchedItem() {
        resyncCounterQueue.async { [weak self] in
            guard let self else { return }
            self.fetchedItemCount += 1
        }
    }

    /// Records that a page of post-resync changes was delivered, so `FullResyncCoordinator`'s Wait 1 can
    /// restart its per-page timeout rather than killing a long multi-page enumeration on the whole-pass budget.
    private func incrementResyncEnumerationPageCount() {
        resyncCounterQueue.async { [weak self] in
            guard let self else { return }
            self.resyncEnumerationPageCount += 1
        }
    }
    
    func enumerateChangesAfterResync(
        fileSystemSlot: FileSystemSlot,
        shareID: String,
        observers: [any NSFileProviderChangeObserver],
        startingAtPage page: Int = 0,
        prospectiveAnchor: (String) throws -> NSFileProviderSyncAnchor
    ) async throws {
        Log.info("Enumerating changes — start (page \(page))", domain: .enumerating)

        // The resync's finish signals — mode reset, working-set flag, temp-file deletion — must fire only
        // when the resync is truly done: the last page, or an error/cancellation. Firing them between
        // intermediate pages would let the coordinator think enumeration finished and would delete the temp
        // file the next page needs to recompute the diff. Only an intermediate (moreComing) page skips them.
        var moreComingDelivered = false
        defer {
            if !moreComingDelivered {
                changesEnumerationMode = .default
                workingSetEnumerationInProgress = false
                try? deleteNodeIdentifiersTempFile()
                try? deleteResyncDiffTempFile()
                diffCache.clear()
            }
        }

        try Task.checkCancellation()

        // Computed once per run and reused across pages (the store is frozen for the whole resync). Both
        // arrays are pre-sorted by rawValue, so a page covers the same items on every re-invocation.
        let diff = try await resolveResyncDiff(fileSystemSlot: fileSystemSlot)

        try Task.checkCancellation()

        let sortedDeletes = diff.deletes.map(NSFileProviderItemIdentifier.init)

        let batchSize = ChangesPaging.batchSize(for: observers)
        let window = Self.pagingWindow(deleteCount: sortedDeletes.count, updateCount: diff.updates.count, batchSize: batchSize, page: page)
        let totalChanges = sortedDeletes.count + diff.updates.count
        let parsedRange = min(page * batchSize, totalChanges) ..< min((page + 1) * batchSize, totalChanges)
        Log.info("Enumerating changes — page \(page): items \(parsedRange) of \(totalChanges) (\(sortedDeletes.count) deletes, \(diff.updates.count) updates), batch \(batchSize), hasMore \(window.hasMore)", domain: .enumerating)

        // Deliver this page's deletes first, then stream the decrypted update groups as each completes.
        let deletedSlice = Array(sortedDeletes[window.deletes])
        if !deletedSlice.isEmpty { observers.forEach { $0.didDeleteItems(withIdentifiers: deletedSlice) } }

        let pageUpdateIdentifiers = Array(diff.updates[window.updates])
        try await decryptAndDeliverUpdates(identifiers: pageUpdateIdentifiers, fileSystemSlot: fileSystemSlot) { items in
            observers.forEach { $0.didUpdate(items) }
        }
        CryptoGo.HelperFreeOSMemory()

        // Page progress restarts the coordinator's per-page Wait 1 timeout.
        incrementResyncEnumerationPageCount()

        let baseAnchor = try prospectiveAnchor(shareID)
        if window.hasMore {
            moreComingDelivered = true
            observers.forEach { $0.finishEnumeratingChanges(upTo: baseAnchor.withResyncPageOffset(page + 1), moreComing: true) }
            Log.info("Enumerating changes — page \(page) delivered, more coming", domain: .enumerating)
        } else {
            observers.forEach { $0.finishEnumeratingChanges(upTo: baseAnchor, moreComing: false) }
            Log.info("Enumerating changes — finished successfully (last page \(page))", domain: .enumerating)
        }
    }

    /// Decrypts the update slice concurrently in groups of `count / 4` (≈4 groups), floored at 1 so a slice
    /// of 1–3 items still produces a group, delivering each group via `deliver` as it completes. `deliver`
    /// runs serially on the enumeration task, so observers (which aren't thread-safe) never see concurrent
    /// calls.
    private func decryptAndDeliverUpdates(
        identifiers: [NodeIdentifier],
        fileSystemSlot: FileSystemSlot,
        deliver: ([NodeItem]) -> Void
    ) async throws {
        guard !identifiers.isEmpty else { return }
        let groupSize = decryptionGroupSizeOverrideForTesting ?? max(1, identifiers.count / 4)
        try await withThrowingTaskGroup(of: [NodeItem].self) { group in
            for identifiersBatch in identifiers.splitInGroups(of: groupSize) {
                group.addTask(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try await Self.decryptNodeItemsGroup(identifiers: identifiersBatch, fileSystemSlot: fileSystemSlot)
                }
            }
            for try await items in group where !items.isEmpty {
                deliver(items)
            }
        }
    }

    /// Fetches one group of update identifiers and maps them to decrypted `NodeItem`s.
    private static func decryptNodeItemsGroup(identifiers: [NodeIdentifier], fileSystemSlot: FileSystemSlot) async throws -> [NodeItem] {
        try await fileSystemSlot.storage.backgroundContextPool.withContext { moc in
            guard let coordinator = moc.persistentStoreCoordinator else {
                throw CocoaError(.coreData)
            }
            return try await moc.perform(schedule: .immediate) {
                let requested = Set(identifiers)
                let fetchRequest = NSFetchRequest<Node>()
                fetchRequest.entity = NSEntityDescription.entity(forEntityName: "Node", in: moc)
                fetchRequest.predicate = NSPredicate(format: "id IN %@", identifiers.map(\.nodeID))
                fetchRequest.includesPropertyValues = true
                fetchRequest.shouldRefreshRefetchedObjects = false
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.relationshipKeyPathsForPrefetching = ["activeRevision", "directShares", "parentLink"]
                guard let nodes = try coordinator.execute(fetchRequest, with: moc) as? [Node] else {
                    throw CocoaError(.coreData)
                }
                // Fetch by id, then keep the intended nodes by full identifier. This disambiguates any
                // cross-volume id reuse and matches SharedWithMe nodes whose stored shareID is empty
                // (shareId, and thus the identifier, derives it).
                return try nodes
                    .filter { requested.contains($0.identifierWithinManagedObjectContext) }
                    .map { try NodeItem(nodeWithinManagedObjectContext: $0) }
            }
        }
    }
    
    /// Returns the run's diff, computed once and cached for reuse across the run's pages. Prefers the
    /// artifact the main app precomputed (`tmp_resync_diff.lz4`), skipping the scan entirely; falls back to
    /// scanning the frozen store against the previous-id snapshot when the artifact is absent or unreadable.
    private func resolveResyncDiff(fileSystemSlot: FileSystemSlot) async throws -> ResyncDiff {
        if let artifactURL = existingResyncDiffArtifactURL() {
            let key = try ResyncDiff.Cache.Key(fileURL: artifactURL)
            return try await diffCache.diff(forKey: key) {
                if let data = try? Data(contentsOf: artifactURL, options: [.uncached]),
                   let diff = try? ResyncDiff.decode(from: data) {
                    Log.info("Enumerating changes — using precomputed diff (\(diff.deletes.count) deletes, \(diff.updates.count) updates)", domain: .enumerating)
                    return diff
                }
                Log.error("Enumerating changes — precomputed diff unreadable, falling back to a full scan", domain: .enumerating)
                return try await self.computeDiffFromScan(fileSystemSlot: fileSystemSlot)
            }
        }
        let key = try ResyncDiff.Cache.Key(fileURL: nodeIdentifiersTempFileURL())
        return try await diffCache.diff(forKey: key) {
            try await self.computeDiffFromScan(fileSystemSlot: fileSystemSlot)
        }
    }

    /// Fallback: scan the frozen store against the previous-id snapshot and compute the diff.
    private func computeDiffFromScan(fileSystemSlot: FileSystemSlot) async throws -> ResyncDiff {
        let previous = try loadNodeIdentifiersFromTempFile()
        Log.info("Enumerating changes — \(previous.count) nodes before refresh", domain: .enumerating)
        let (updateCandidates, deletedState) = try await Self.scanCurrentIdentifiers(fileSystemSlot: fileSystemSlot)
        Log.info("Enumerating changes — \(updateCandidates.count + deletedState.count) nodes after refresh", domain: .enumerating)
        return ResyncDiff.computeResyncDiff(
            previous: previous, updateCandidates: updateCandidates, deletedState: deletedState
        )
    }

    /// Scans the frozen store once, partitioning present nodes into non-deleted update candidates and
    /// deleted-state identifiers (via the shared `ResyncDiff.scanIdentifiers`).
    private static func scanCurrentIdentifiers(
        fileSystemSlot: FileSystemSlot
    ) async throws -> (updateCandidates: [NodeIdentifier], deletedState: [NodeIdentifier]) {
        try await fileSystemSlot.storage.backgroundContextPool.withContext { moc in
            try await ResyncDiff.scanIdentifiers(in: moc, batchSize: Self.numberOfNodesProcessedPerChildContext)
        }
    }

    func forceItemsEnumeration(observers: [NSFileProviderChangeObserver], syncAnchor: NSFileProviderSyncAnchor) {
        // forces the `enumerateItems`
        observers.forEach {
            if $0 is ChangeEnumerationObserver {
                $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
            } else {
                $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
            }
        }
        Log.info("Forcing items reenumeration", domain: .enumerating)
        changesEnumerationMode = .default
    }
    
    /// Encodes node identifiers to the on-disk snapshot format (JSON + LZ4).
    public static func compressedData(for nodeIDs: [NodeIdentifier]) throws -> Data {
        let data = try JSONEncoder().encode(nodeIDs) as NSData
        return try data.compressed(using: nodeIdentifiersTempFileCompressionAlgorithm) as Data
    }

    /// Decodes node identifiers from the on-disk snapshot format written by `compressedData(for:)`.
    public static func decodeNodeIdentifiers(from data: Data) throws -> [NodeIdentifier] {
        let decompressed = try (data as NSData).decompressed(using: nodeIdentifiersTempFileCompressionAlgorithm) as Data
        return try JSONDecoder().decode([NodeIdentifier].self, from: decompressed)
    }

    private func loadNodeIdentifiersFromTempFile() throws -> [NodeIdentifier] {
        let fileURL = try nodeIdentifiersTempFileURL()
        let data = try Data(contentsOf: fileURL, options: [.uncached])
        let nodeIDs = try Self.decodeNodeIdentifiers(from: data)
        Log.info("Successfully loaded \(nodeIDs.count) node IDs from temporary file", domain: .resyncing)
        return nodeIDs
    }
    
    func deleteNodeIdentifiersTempFile() throws {
        let fileURL = try nodeIdentifiersTempFileURL()
        try FileManager.default.removeItem(at: fileURL)
    }
    
    private func nodeIdentifiersTempFileURL() throws -> URL {
        // Reads from the injected suite's directory. For the production `.group` suite this is the
        // app-group container — the same location `FullResyncCoordinator` writes the file to.
        settingsStorage.directoryUrl.appendingPathComponent(Self.nodeIdentifiersTempFileName)
    }

    private func resyncDiffTempFileURL() throws -> URL {
        settingsStorage.directoryUrl.appendingPathComponent(ResyncDiff.resyncDiffTempFileName)
    }

    /// The precomputed-diff artifact URL when it exists on disk, else nil.
    private func existingResyncDiffArtifactURL() -> URL? {
        guard let fileURL = try? resyncDiffTempFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    func deleteResyncDiffTempFile() throws {
        let fileURL = try resyncDiffTempFileURL()
        try FileManager.default.removeItem(at: fileURL)
    }
}

extension ResyncEnumerationService {
    /// One page of the post-resync change stream. The stream is ordered deletes-first: global indices
    /// `[0, deleteCount)` are deletes and `[deleteCount, deleteCount + updateCount)` are updates, so a
    /// page can cover deletes only, updates only, or straddle the boundary. `deletes`/`updates` are
    /// ranges into the respective ordered arrays; `hasMore` is true when further pages remain.
    struct PageWindow: Equatable {
        let deletes: Range<Int>
        let updates: Range<Int>
        let hasMore: Bool
    }

    /// Splits the combined deletes+updates change stream into the `page`-th window of `batchSize` items.
    /// Pure and total: returns empty ranges for pages past the end, and treats `batchSize < 1` as 1.
    static func pagingWindow(deleteCount: Int, updateCount: Int, batchSize: Int, page: Int) -> PageWindow {
        let batchSize = max(1, batchSize)
        let total = deleteCount + updateCount
        let windowStart = min(max(0, page) * batchSize, total)
        let windowEnd = min(windowStart + batchSize, total)
        let deletes = min(windowStart, deleteCount) ..< min(windowEnd, deleteCount)
        let updates = (max(windowStart, deleteCount) - deleteCount) ..< (max(windowEnd, deleteCount) - deleteCount)
        return PageWindow(deletes: deletes, updates: updates, hasMore: windowEnd < total)
    }
}
