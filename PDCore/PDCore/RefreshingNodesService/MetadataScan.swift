// Copyright (c) 2026 Proton AG
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

import CoreData
import Foundation
import PDClient

enum MetadataScanKind {
    case folders
    case files
}

/// Fetches and saves the metadata of discovered nodes. Run as two passes: `.folders` first, then `.files`.
///
/// Pending nodes are pulled shallowest-first and processed in windows; each window's 150-link chunks (the
/// backend cap) are fetched in parallel, then saved in one pass. `sortedLinks` orders parents before
/// children within a window, and the shallowest-first windowing guarantees a folder is saved before its
/// children — so `CloudSlot.update` always finds a fully-saved parent (never a stub, which would fail Core
/// Data validation). Files are leaves so their order is immaterial; and because the file pass runs after
/// the folder pass, a file's parent folder is always already saved.
///
/// A node absent from the metadata response was permanently deleted: it is dropped and the total node
/// count decremented. Saved nodes are faulted after each window to keep memory bounded.
///
/// A stub-parent validation error (the rare moved-into-a-new-folder case) propagates here; late-parent
/// resolution will catch it.
final class MetadataScan: @unchecked Sendable {
    private let kind: MetadataScanKind
    private let metadataDataSource: RemoteLinksMetadataByVolumeDataSource
    private let cloudUpdater: CloudUpdaterProtocol
    private let workQueue: ResyncMetadataRepository
    private let moc: NSManagedObjectContext
    private let shareID: String
    private let volumeID: String
    private let retryConfiguration: HttpClientResilience.Configuration
    private let metadataBatchSize: Int
    private let maxConcurrentFetches: Int
    private let lateParentResolver: LateParentResolver?
    /// Called after each saved window so the scan can report determinate "X of Y" progress.
    private let onProgress: () async -> Void
    private let reporter: FullResyncMetricsReporting

    private var windowSize: Int { metadataBatchSize * maxConcurrentFetches }

    init(
        kind: MetadataScanKind,
        metadataDataSource: RemoteLinksMetadataByVolumeDataSource,
        cloudUpdater: CloudUpdaterProtocol,
        workQueue: ResyncMetadataRepository,
        moc: NSManagedObjectContext,
        shareID: String,
        volumeID: String,
        retryConfiguration: HttpClientResilience.Configuration = .forDriveAPICalls,
        metadataBatchSize: Int = 150,
        maxConcurrentFetches: Int = 16,
        lateParentResolver: LateParentResolver? = nil,
        onProgress: @escaping () async -> Void = {},
        reporter: FullResyncMetricsReporting
    ) {
        self.kind = kind
        self.metadataDataSource = metadataDataSource
        self.cloudUpdater = cloudUpdater
        self.workQueue = workQueue
        self.moc = moc
        self.shareID = shareID
        self.volumeID = volumeID
        self.retryConfiguration = retryConfiguration
        self.metadataBatchSize = metadataBatchSize
        self.maxConcurrentFetches = maxConcurrentFetches
        self.lateParentResolver = lateParentResolver
        self.onProgress = onProgress
        self.reporter = reporter
    }

    func fetchAndSave() async throws {
        var ids = try await nextPendingIDs(limit: windowSize)
        while !ids.isEmpty {
            try Task.checkCancellation()
            try await fetchAndSave(ids: ids)
            await onProgress()
            try Task.checkCancellation()
            ids = try await nextPendingIDs(limit: windowSize)
        }
    }

    private func nextPendingIDs(limit: Int) async throws -> [String] {
        switch kind {
        case .folders: return try await workQueue.nextPendingFolderIDs(limit: limit)
        case .files: return try await workQueue.nextPendingFileIDs(limit: limit)
        }
    }

    private func fetchAndSave(ids: [String]) async throws {
        let (responses, failedIDs) = try await fetchChunks(ids.splitInGroups(of: metadataBatchSize))
        // Concatenating each chunk's parent-ordered links, in chunk order, keeps parents before children
        // across the whole window (chunks are consecutive slices of the shallowest-first window).
        let sortedLinks = responses.flatMap { $0.sortedLinks }
        let returnedIDs = Set(sortedLinks.map(\.linkID))

        // Resolve any parent this batch references that the scan never discovered, so the save below finds
        // a fully-saved parent instead of a stub.
        try await resolveUnknownParentsIfNeeded(in: sortedLinks, presentIDs: returnedIDs)

        // A folder whose metadata fetch failed can't be saved, so its children in this batch would hit a stub
        // parent. Drop those descendants from the save; the whole subtree is abandoned in the queue below.
        let orphanedByFailure = kind == .folders ? descendantsOfFailedFolders(in: sortedLinks, failed: Set(failedIDs)) : []
        let saveableLinks = orphanedByFailure.isEmpty ? sortedLinks : sortedLinks.filter { !orphanedByFailure.contains($0.linkID) }

        // Only IDs from chunks that were fetched are saved-or-deleted; a chunk whose fetch kept failing is
        // abandoned (marked failed below) so the rest of the scan proceeds.
        let attemptedIDs = Set(ids).subtracting(failedIDs)
        let deletedIDs = attemptedIDs.subtracting(returnedIDs)
        let savedIDs = attemptedIDs.subtracting(deletedIDs).subtracting(orphanedByFailure)

        let savedNodes = cloudUpdater.update(saveableLinks, of: shareID, in: moc)
        try moc.performAndWait {
            try self.moc.save()
            savedNodes.forEach { self.moc.refresh($0, mergeChanges: false) }
        }

        // Durability: dequeue only after the save has committed.
        try await workQueue.markMetadataFetchedAndSaved(Array(savedIDs))
        if !deletedIDs.isEmpty {
            try await workQueue.dropDeletedNodes(Array(deletedIDs))
        }
        if !failedIDs.isEmpty {
            if kind == .folders {
                // A failed folder takes its whole subtree with it — descendants can't be saved.
                try await workQueue.markFolderSubtreesFailed(failedIDs)
            } else {
                try await workQueue.markMetadataFetchingFailed(failedIDs)
            }
        }
    }

    /// Within one batch, the IDs that transitively descend from a folder whose metadata fetch failed. They
    /// can't be saved (their parent will be missing), so they're dropped from the save and abandoned with the
    /// rest of the subtree.
    private func descendantsOfFailedFolders(in links: [Link], failed: Set<String>) -> Set<String> {
        guard !failed.isEmpty else { return [] }
        var abandoned = failed
        var changed = true
        while changed {
            changed = false
            for link in links where !abandoned.contains(link.linkID) {
                if let parent = link.parentLinkID, abandoned.contains(parent) {
                    abandoned.insert(link.linkID)
                    changed = true
                }
            }
        }
        return abandoned.subtracting(failed)
    }

    /// Detects parents referenced by the batch that the scan never discovered (neither in the batch nor a
    /// known folder) and resolves them before the save. No-op unless a resolver is configured.
    private func resolveUnknownParentsIfNeeded(in links: [Link], presentIDs: Set<String>) async throws {
        guard let lateParentResolver else { return }
        let parentIDs = Set(links.compactMap(\.parentLinkID))
        let outOfBatchParents = parentIDs.subtracting(presentIDs)
        guard !outOfBatchParents.isEmpty else { return }
        let knownFolders = try await workQueue.knownFolderIDs(among: Array(outOfBatchParents))
        let unknownParents = outOfBatchParents.subtracting(knownFolders)
        guard !unknownParents.isEmpty else { return }
        try await lateParentResolver.resolve(unknownParentIDs: unknownParents)
    }

    /// Fetches the chunks concurrently (each retried on transient failures) and returns the responses in
    /// chunk order. A chunk that keeps failing after retries has its IDs collected into `failedIDs` — the
    /// failure is isolated so the scan continues — instead of failing the whole scan; cancellation propagates.
    private func fetchChunks(_ chunks: [[String]]) async throws -> (responses: [LinksResponseByVolume], failedIDs: [String]) {
        try await withThrowingTaskGroup(of: (Int, LinksResponseByVolume?, [String]).self) { group in
            for (index, chunk) in chunks.enumerated() {
                group.addTask {
                    do {
                        let response = try await ScanRetry.perform(configuration: self.retryConfiguration) {
                            try await self.metadataDataSource.getMetadata(forLinks: chunk, inVolume: self.volumeID)
                        }
                        return (index, response, [])
                    } catch {
                        if Task.isCancelled { throw error }
                        self.reporter.reportError(type: DriveFullResyncErrorType.classify(error), engine: .v2)
                        return (index, nil, chunk)
                    }
                }
            }
            var responses: [(Int, LinksResponseByVolume)] = []
            var failedIDs: [String] = []
            for try await (index, response, failedChunk) in group {
                if let response {
                    responses.append((index, response))
                }
                failedIDs.append(contentsOf: failedChunk)
            }
            return (responses.sorted { $0.0 < $1.0 }.map(\.1), failedIDs)
        }
    }
}
