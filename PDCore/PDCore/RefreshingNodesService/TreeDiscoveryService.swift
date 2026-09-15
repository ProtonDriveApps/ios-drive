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

import Foundation

/// Walks the tree from a starting folder, streaming discovered folders and nodes into the work queue.
///
/// Each folder is listed twice, because the children endpoint returns only link IDs (no type): once with
/// `FoldersOnly=1` to learn which children are subfolders (those recurse), then with `FoldersOnly=0` to get
/// all children (files = all − subfolders). Subfolders are enqueued for further listing and for metadata;
/// files are enqueued for metadata only.
///
/// Folders are listed in bounded-concurrency batches: a batch of not-yet-listed folders is pulled from the
/// work queue and listed in parallel, then the next batch (which now includes any subfolders just found) is
/// pulled, until no unlisted folders remain. IDs are streamed to the work queue per page, so only one
/// folder's subfolder set is held in memory at a time. Reused by late-parent resolution to discover a
/// newly-found subtree.
final class TreeDiscoveryService: @unchecked Sendable {
    private let childrenLister: FolderChildrenLister
    private let workQueue: ResyncMetadataRepository
    private let volumeID: String
    private let maxConcurrentFolders: Int
    private let reporter: FullResyncMetricsReporting

    init(
        childrenLister: FolderChildrenLister,
        workQueue: ResyncMetadataRepository,
        volumeID: String,
        maxConcurrentFolders: Int = 16,
        reporter: FullResyncMetricsReporting
    ) {
        self.childrenLister = childrenLister
        self.workQueue = workQueue
        self.volumeID = volumeID
        self.maxConcurrentFolders = maxConcurrentFolders
        self.reporter = reporter
    }

    /// Discovers `startFolder` and everything beneath it. Seeds the work queue with `startFolder` (for
    /// listing, not for metadata — the caller owns the starting folder's own metadata) and processes the
    /// unlisted folders until none remain.
    /// `onDiscovered` is called after each batch of folders is listed, with the running discovered-node count
    /// — the scan uses it to report indeterminate "discovering N…" progress. No-op by default (the late-parent
    /// resolver reuses discovery for a subtree and doesn't drive the UI).
    func discoverFiles(inside startFolder: UnlistedFolder, onDiscovered: (Int) async -> Void = { _ in }) async throws {
        try await workQueue.enqueueFoldersForChildrenListing([startFolder])

        var folders = try await workQueue.nextUnlistedFolders(limit: maxConcurrentFolders)
        while !folders.isEmpty {
            try Task.checkCancellation()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for folder in folders {
                    group.addTask { try await self.listChildren(of: folder) }
                }
                try await group.waitForAll()
            }
            await onDiscovered(try await workQueue.totalNumberOfNodes())
            try Task.checkCancellation()
            folders = try await workQueue.nextUnlistedFolders(limit: maxConcurrentFolders)
        }
    }

    private func listChildren(of folder: UnlistedFolder) async throws {
        try Task.checkCancellation()
        do {
            let childDepth = folder.depth + 1

            // The two listings are independent network calls (subfolders, then all children), so run them
            // concurrently. Files can only be told from subfolders once both finish (v2 `/children` omits
            // type), so the results are combined after: files = all children − subfolders.
            async let subfolders = collectChildrenIDs(of: folder.id, foldersOnly: true)
            async let allChildren = collectChildrenIDs(of: folder.id, foldersOnly: false)
            let subfolderIDs = try await subfolders
            let allChildIDs = try await allChildren
            let fileIDs = allChildIDs.subtracting(subfolderIDs)

            // Subfolders recurse (listing) and need metadata; files need metadata only.
            try await workQueue.enqueueFoldersForChildrenListing(
                subfolderIDs.map { UnlistedFolder(id: $0, parentID: folder.id, depth: childDepth) }
            )
            try await workQueue.enqueueNodesForMetadataFetching(
                subfolderIDs.map { PendingNode(id: $0, parentID: folder.id, isFolder: true, depth: childDepth) }
                    + fileIDs.map { PendingNode(id: $0, parentID: folder.id, isFolder: false, depth: childDepth) }
            )

            try await workQueue.markChildrenListingDone(folderID: folder.id)
        } catch {
            // Cancellation (pause/stop) aborts the whole scan so it can resume later; a permanent listing
            // failure is isolated — this folder's subtree is abandoned and its siblings keep going.
            if Task.isCancelled { throw error }
            Log.error("Sync v2: children listing failed permanently, abandoning subtree", error: error, domain: .syncing)
            reporter.reportError(type: DriveFullResyncErrorType.classify(error), engine: .v2)
            try await workQueue.markChildrenListingFailed(folderID: folder.id)
        }
    }

    /// Lists every page of a folder's children (subfolders only, or all children) and returns their IDs.
    private func collectChildrenIDs(of folderID: String, foldersOnly: Bool) async throws -> Set<String> {
        var ids = Set<String>()
        try await childrenLister.listAllChildren(volumeID: volumeID, folderID: folderID, foldersOnly: foldersOnly) { pageIDs in
            ids.formUnion(pageIDs)
        }
        return ids
    }
}
