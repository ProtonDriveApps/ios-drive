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

/// A node (folder or file) discovered during the scan whose metadata has not been fetched and saved yet.
struct PendingNode: Equatable {
    let id: String
    let parentID: String?
    let isFolder: Bool
    /// Distance from the scan root (root = 0). Lets the metadata phase save a parent before its children.
    let depth: Int
}

/// A folder that is known but whose children have not been listed yet.
///
/// Discovery works through the set of unlisted folders: it starts with only the root, and listing a folder
/// removes it from the set and adds the subfolders it reveals. Discovery is done when no unlisted folder
/// remains. A folder leaves the set only once its children are fully listed (`markChildrenListingDone`), so
/// an interruption mid-listing re-lists it from the first page on resume (idempotent, just less efficient).
struct UnlistedFolder: Equatable {
    let id: String
    /// The parent folder's id, or nil for the scan root.
    let parentID: String?
    /// Distance from the scan root (root = 0).
    let depth: Int

    init(id: String, parentID: String?, depth: Int) {
        self.id = id
        self.parentID = parentID
        self.depth = depth
    }
}

/// Persisted scratch store for a single full-resync scan. The engine depends only on this protocol, so
/// the backing store (CoreData / SQLite / file / in-memory) is swappable. The protocol owns its store
/// lifecycle (create / open / delete).
///
/// The scan has two phases, and this queue holds the outstanding work for both.
///
/// **1. Discovery** walks the tree to find every node, starting from the root:
///   - `enqueueFoldersForChildrenListing([root])` adds the root to the set of unlisted folders.
///   - `nextUnlistedFolders(limit:)` hands back a batch of not-yet-listed folders.
///   - For each, the engine lists all of its children, then calls `enqueueFoldersForChildrenListing`
///     (subfolders become unlisted folders) and `enqueueNodesForMetadataFetching` (every child — folder or
///     file — needs its metadata later).
///   - `markChildrenListingDone` when the last page is listed, or `markChildrenListingFailed` if listing
///     keeps failing (the subtree is abandoned, siblings continue).
///   - Discovery ends when no unlisted folder remains; `totalNumberOfNodes` is then the true node count.
///
/// **2. Metadata** fetches and saves each discovered node:
///   - `nextPendingFolderIDs` / `nextPendingFileIDs` hand back batches (folders shallowest-first, so a
///     parent is saved before its children).
///   - `markMetadataFetchedAndSaved` once a node's metadata is written to the recovery store, or
///     `markMetadataFetchingFailed` if it keeps failing.
///
/// The scan is finished when `hasOutstandingWork` is false; `failedItems` then lists anything abandoned.
///
/// Durability contract: for on-disk implementations every mutating call is committed (durable) on return.
/// The engine's checkpoint discipline relies on the ordering save-node-then-`markMetadataFetchedAndSaved`
/// (a node is dequeued only after its metadata is durably saved).
protocol ResyncMetadataRepository {
    // MARK: Discovery — listing folders' children

    /// Adds folders to the set of unlisted folders (folders still waiting to have their children listed).
    func enqueueFoldersForChildrenListing(_ folders: [UnlistedFolder]) async throws

    /// Adds nodes (folders and files) to the metadata queue. Every discovered node is enqueued here
    /// exactly once, so this call is what advances `totalNumberOfNodes`.
    func enqueueNodesForMetadataFetching(_ nodes: [PendingNode]) async throws

    /// A batch of unlisted folders to list, shallowest first. Returns up to `limit` at once so discovery
    /// can list several folders concurrently (bounded fan-out) instead of one at a time.
    func nextUnlistedFolders(limit: Int) async throws -> [UnlistedFolder]

    /// Marks a folder's children as fully listed; it leaves the unlisted set.
    func markChildrenListingDone(folderID: String) async throws

    /// Marks a folder's children-listing as permanently failed (retries exhausted): it leaves the unlisted
    /// set, its subtree stays undiscovered, siblings keep going. Sets the folder's `failed` flag, so it
    /// appears in `failedItems`.
    func markChildrenListingFailed(folderID: String) async throws

    // MARK: Metadata — fetching nodes' metadata

    /// Pending folder IDs to fetch, shallowest first, so a parent is saved before its children.
    func nextPendingFolderIDs(limit: Int) async throws -> [String]

    /// Pending file IDs to fetch. Files are leaves, so any order is fine.
    func nextPendingFileIDs(limit: Int) async throws -> [String]

    /// Removes nodes whose metadata was fetched and saved to the recovery store. Does not change
    /// `totalNumberOfNodes` — a saved node is still one of the discovered nodes.
    func markMetadataFetchedAndSaved(_ ids: [String]) async throws

    /// Marks nodes whose metadata fetch permanently failed (retries exhausted): they stop counting as
    /// pending and appear in `failedItems`. Sets the pending node's `failed` flag.
    func markMetadataFetchingFailed(_ ids: [String]) async throws

    /// Marks each given folder and its entire subtree (transitive descendants) as failed. Used when a
    /// folder's metadata fetch is abandoned: its descendants can never be saved (their parent is missing),
    /// so the whole subtree is abandoned together.
    func markFolderSubtreesFailed(_ folderIDs: [String]) async throws

    /// Drops nodes that turned out to be permanently deleted (absent from the metadata response): removes
    /// them from the queue and decrements `totalNumberOfNodes`, since they will never be saved.
    func dropDeletedNodes(_ ids: [String]) async throws

    // MARK: State

    /// Number of nodes discovered so far — the progress denominator (Y). Grows as discovery finds nodes;
    /// equals the true node count once discovery completes.
    func totalNumberOfNodes() async throws -> Int

    /// How many discovered nodes still need their metadata fetched (excludes saved and failed nodes).
    func pendingNodesCount() async throws -> Int

    /// True while any work remains: at least one folder still to list, or one node still to fetch. Failed
    /// items are abandoned and do not count as work, so a scan can finish with `hasOutstandingWork == false`
    /// while `failedItems` is non-empty.
    func hasOutstandingWork() async throws -> Bool

    /// IDs of everything abandoned after retries: both folders whose children-listing failed and nodes
    /// whose metadata fetch failed.
    func failedItems() async throws -> [String]

    /// Of the given IDs, the ones the scan has discovered as folders (they have a work-queue entry). Used
    /// to spot a node whose parent was never discovered — the late/moved-parent case.
    func knownFolderIDs(among ids: [String]) async throws -> Set<String>

    // MARK: Lifecycle

    /// Clears the `failed` flag on every abandoned folder and node so a resume re-attempts them (a folder
    /// becomes unlisted again; a node becomes pending again).
    func resetFailedItems() async throws

    /// Clears all rows to start a fresh scan over an existing store.
    func reset() async throws

    /// Deletes the backing store and its files.
    func tearDown() async throws
}
