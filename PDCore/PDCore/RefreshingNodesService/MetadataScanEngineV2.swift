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
import Dispatch
import Foundation
import PDClient

/// The v2 sync scan engine. Discovers the whole tree, fetches and saves every node's metadata, then
/// flags every folder fully-fetched and reports the counts. Runs three phases over the shared work-queue:
///
/// 1. Discovery streams the tree into the work-queue (folders to list + nodes to fetch).
/// 2. The folder metadata pass saves folders parent-first; the file pass saves files.
/// 3. Repeat the passes until no work remains — late-parent resolution can discover new subtrees
///    mid-pass, so a pass can leave behind freshly-enqueued work.
///
/// On completion it marks every folder `isChildrenListFullyFetched` in one batch, tears the work-queue
/// down, and returns the node counts. The recovery-store swap is `FullResyncService`'s job.
final class MetadataScanEngineV2: MetadataScanEngine, @unchecked Sendable {
    enum ScanError: Error {
        case rootNotFound
    }

    private let childrenListerDataSource: FolderChildrenListV2DataSource
    private let metadataDataSource: RemoteLinksMetadataByVolumeDataSource
    private let cloudUpdater: CloudUpdaterProtocol
    private let ancestorResolver: ScanNodeAncestorResolving
    private let makeWorkQueue: () throws -> ResyncMetadataRepository
    private let storage: StorageManager
    private let retryConfiguration: HttpClientResilience.Configuration
    private let reporter: FullResyncMetricsReporting

    // A fresh work queue is built per scan: `tearDown` deletes its backing store at the end of a run, so a
    // single instance can't be reused across scans.
    init(
        childrenListerDataSource: FolderChildrenListV2DataSource,
        metadataDataSource: RemoteLinksMetadataByVolumeDataSource,
        cloudUpdater: CloudUpdaterProtocol,
        ancestorResolver: ScanNodeAncestorResolving,
        makeWorkQueue: @escaping () throws -> ResyncMetadataRepository,
        storage: StorageManager,
        retryConfiguration: HttpClientResilience.Configuration = .forDriveAPICalls,
        reporter: FullResyncMetricsReporting
    ) {
        self.childrenListerDataSource = childrenListerDataSource
        self.metadataDataSource = metadataDataSource
        self.cloudUpdater = cloudUpdater
        self.ancestorResolver = ancestorResolver
        self.makeWorkQueue = makeWorkQueue
        self.storage = storage
        self.retryConfiguration = retryConfiguration
        self.reporter = reporter
    }

    // v2 `/children` always includes trashed nodes.
    func scanMetadata(
        root: Folder,
        volumeID: String,
        resume: Bool,
        cancelToken: CancelToken?,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport {
        let task = Task { try await self.runScan(root: root, volumeID: volumeID, resume: resume, onNodesRefreshed: onNodesRefreshed) }
        cancelToken?.onCancel = { task.cancel() }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func runScan(
        root: Folder,
        volumeID: String,
        resume: Bool,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport {
        // A fresh context owned by this scan: nobody else holds it, so the batch-update reset below only
        // affects our own objects, and the scan is isolated from other writers.
        let moc = storage.newBackgroundContext()
        let rootObjectID = root.objectID
        // id and shareID come from the node; volumeID is passed in because the node's volumeID is empty on macOS.
        let rootFolder: (id: String, shareID: String, volumeID: String) = try moc.performAndWait {
            guard let root = try moc.existingObject(with: rootObjectID) as? Folder else {
                throw ScanError.rootNotFound
            }
            return (id: root.id, shareID: root.shareID, volumeID: volumeID)
        }

        // Fresh per scan. A fresh run clears any rows a crashed prior run left in the on-disk store; a resume
        // keeps them so discovery and the metadata passes continue, but clears the failed flags so items
        // abandoned on the prior run are re-attempted.
        let workQueue = try makeWorkQueue()
        if resume {
            try await workQueue.resetFailedItems()
        } else {
            try await workQueue.reset()
        }

        let lister = FolderChildrenLister(dataSource: childrenListerDataSource, retryConfiguration: retryConfiguration)
        let treeDiscoveryService = TreeDiscoveryService(childrenLister: lister, workQueue: workQueue, volumeID: rootFolder.volumeID, reporter: reporter)
        let resolver = ScanLateParentResolver(
            ancestorResolver: ancestorResolver, treeDiscoveryService: treeDiscoveryService, shareID: rootFolder.shareID, moc: moc
        )
        // Metadata progress: "X of Y" where Y is the discovered total and X is the processed count
        // (total − still-pending). Resume-safe (prior-saved nodes aren't pending) and counts abandoned items.
        let onMetadataProgress: () async -> Void = {
            let total = (try? await workQueue.totalNumberOfNodes()) ?? 0
            let pending = (try? await workQueue.pendingNodesCount()) ?? 0
            await onNodesRefreshed(max(0, total - pending), total)
        }
        let folderPass = metadataScan(.folders, root: rootFolder, moc: moc, workQueue: workQueue, resolver: resolver, onProgress: onMetadataProgress)
        let filePass = metadataScan(.files, root: rootFolder, moc: moc, workQueue: workQueue, resolver: resolver, onProgress: onMetadataProgress)

        // Discovery progress is indeterminate (total isn't known until discovery ends): report the growing count.
        // Monotonic per-phase clocks feed the speed histogram. The work-queue counts are cumulative across
        // attempts, so on a resume subtract the pre-phase baseline to report only the nodes handled this attempt.
        let discoveryStart = DispatchTime.now()
        let discoveredAtStart = (try? await workQueue.totalNumberOfNodes()) ?? 0
        var fetchStart: DispatchTime?
        var processedAtFetchStart = 0
        var lastDiscovered = 0
        do {
            try await treeDiscoveryService.discoverFiles(inside: UnlistedFolder(id: rootFolder.id, parentID: nil, depth: 0)) { discovered in
                lastDiscovered = discovered
                await onNodesRefreshed(discovered, nil)
            }
            reporter.reportSpeed(step: .nodesDiscovery, engine: .v2, nodeCount: max(0, lastDiscovered - discoveredAtStart), elapsed: Self.elapsedSeconds(since: discoveryStart))

            // Emit the post-discovery baseline before the passes churn: a fresh run shows 0 of Y, a resume shows
            // the count it left off at (not 0). Placed after discovery so the total is already known.
            let fetchStarted = DispatchTime.now()
            fetchStart = fetchStarted
            processedAtFetchStart = (try? await processedNodeCount(in: workQueue)) ?? 0
            await onMetadataProgress()

            // Passes run until the queue drains: late-parent resolution can enqueue new work during a pass.
            repeat {
                try Task.checkCancellation()
                try await folderPass.fetchAndSave()
                try await filePass.fetchAndSave()
            } while try await workQueue.hasOutstandingWork()
            // Metrics-only query: never let it fail an already-completed scan.
            let processed = (try? await processedNodeCount(in: workQueue)) ?? 0
            reporter.reportSpeed(step: .metadataFetch, engine: .v2, nodeCount: max(0, processed - processedAtFetchStart), elapsed: Self.elapsedSeconds(since: fetchStarted))
        } catch {
            // Any mid-scan stop emits the current phase's partial speed (a pause/cancel surfaces as
            // URLError.cancelled, not CancellationError). The original error is rethrown for the coordinator to route.
            if let fetchStart {
                let processed = (try? await processedNodeCount(in: workQueue)) ?? 0
                reporter.reportSpeed(step: .metadataFetch, engine: .v2, nodeCount: max(0, processed - processedAtFetchStart), elapsed: Self.elapsedSeconds(since: fetchStart))
            } else {
                reporter.reportSpeed(step: .nodesDiscovery, engine: .v2, nodeCount: max(0, lastDiscovered - discoveredAtStart), elapsed: Self.elapsedSeconds(since: discoveryStart))
            }
            throw error
        }

        // A folder whose listing failed is not fully fetched, so exclude it from the flag; any failed files
        // in the set simply don't match a Folder row.
        let failedIDs = try await workQueue.failedItems()
        let discoveredTotal = try await workQueue.totalNumberOfNodes()
        try await markAllFoldersFullyFetched(in: moc, excluding: failedIDs)
        let counts = try await countSavedNodes(in: moc)
        let report = RefreshedNodesReport(active: counts.active, total: counts.total, failed: failedIDs.count)

        // A clean run discards the scratch store; when items were abandoned, keep it so a resume (Retry) can
        // re-attempt them.
        if failedIDs.isEmpty {
            try await workQueue.tearDown()
        } else {
            Log.error("Sync v2 completed with \(failedIDs.count) abandoned item(s) after retries; work queue preserved for retry", domain: .syncing)
        }
        // Final determinate update: X == Y, consistent with the per-window "X of Y" progress above.
        await onNodesRefreshed(discoveredTotal, discoveredTotal)
        return report
    }

    private func processedNodeCount(in workQueue: ResyncMetadataRepository) async throws -> Int {
        let total = try await workQueue.totalNumberOfNodes()
        let pending = try await workQueue.pendingNodesCount()
        return max(0, total - pending)
    }

    private static func elapsedSeconds(since start: DispatchTime) -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }

    private func metadataScan(
        _ kind: MetadataScanKind,
        root: (id: String, shareID: String, volumeID: String),
        moc: NSManagedObjectContext,
        workQueue: ResyncMetadataRepository,
        resolver: LateParentResolver,
        onProgress: @escaping () async -> Void
    ) -> MetadataScan {
        MetadataScan(
            kind: kind,
            metadataDataSource: metadataDataSource,
            cloudUpdater: cloudUpdater,
            workQueue: workQueue,
            moc: moc,
            shareID: root.shareID,
            volumeID: root.volumeID,
            retryConfiguration: retryConfiguration,
            lateParentResolver: resolver,
            onProgress: onProgress,
            reporter: reporter
        )
    }

    /// Flags folders in the recovery store fully-fetched, except `excludedIDs` (folders whose listing failed,
    /// so their children are incomplete). Production uses a batch update, then resets the context so its
    /// cached objects reflect the store (a batch update bypasses the context). In-memory stores (tests) don't
    /// support batch updates, so they fall back to updating each folder in the context.
    private func markAllFoldersFullyFetched(in moc: NSManagedObjectContext, excluding excludedIDs: [String]) async throws {
        try await moc.perform {
            let predicate = excludedIDs.isEmpty ? nil : NSPredicate(format: "NOT (id IN %@)", excludedIDs)
            if moc.isInMemory {
                let request = NSFetchRequest<Folder>(entityName: "Folder")
                request.predicate = predicate
                for folder in try moc.fetch(request) {
                    folder.isChildrenListFullyFetched = true
                }
                try moc.save()
            } else {
                let request = NSBatchUpdateRequest(entityName: "Folder")
                request.predicate = predicate
                request.propertiesToUpdate = ["isChildrenListFullyFetched": true]
                try moc.execute(request)
                moc.reset()
            }
        }
    }

    /// Counts saved nodes for the report: `total` is every saved node, `active` excludes trashed and
    /// trash-inheriting nodes (matching v1). The active pass walks ancestors per node, so it iterates a
    /// batched fetch and faults nodes as it goes to bound memory.
    private func countSavedNodes(in moc: NSManagedObjectContext) async throws -> (active: Int, total: Int) {
        try await moc.perform {
            let total = try moc.count(for: NSFetchRequest<Node>(entityName: "Node"))

            let activeRequest = NSFetchRequest<Node>(entityName: "Node")
            activeRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Node.stateRaw), NSNumber(value: Node.State.active.rawValue))
            activeRequest.fetchBatchSize = 500
            var active = 0
            for node in try moc.fetch(activeRequest) {
                if !node.isTrashInheriting { active += 1 }
                moc.refresh(node, mergeChanges: false)
            }
            return (active: active, total: total)
        }
    }
}
