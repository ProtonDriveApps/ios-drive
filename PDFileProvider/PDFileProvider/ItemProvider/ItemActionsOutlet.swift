// Copyright (c) 2023 Proton AG
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
import PDCore
import CoreData

public typealias CreateFilePerformerProvider = () async -> CreateFilePerformer

public protocol CreateFilePerformer {

    // swiftlint:disable:next function_parameter_count
    func createFile(tower: Tower,
                    item: NSFileProviderItem,
                    with contents: URL?,
                    under parent: Folder,
                    progress: Progress?,
                    logOperation: Bool,
                    moc: NSManagedObjectContext) async throws -> Node
}

public typealias NewRevisionUploadPerformerProvider = () async -> NewRevisionUploadPerformer

public protocol NewRevisionUploadPerformer {

    // swiftlint:disable:next function_parameter_count
    func uploadNewRevision(item: NSFileProviderItem, file: File, tower: Tower, copy: URL, fileSize: Int, pendingFields: NSFileProviderItemFields, progress: Progress?, moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
}

public final class ItemActionsOutlet {
    public typealias SuccessfulCompletion = (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    public typealias Completion = (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private typealias ProgressFunction = (Tower, NSFileProviderItem, NSFileProviderItemVersion, NSFileProviderItemFields, URL?, Progress?, NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)

    private let fileProviderManager: NSFileProviderManager
    private let instanceIdentifier = UUID()
    let fileCreationProvider: CreateFilePerformerProvider
    let newRevisionUploadPerformerProvider: NewRevisionUploadPerformerProvider
    public let providersPipeline: DriveObservabilityPipeline
    
    private let folderRateLimiter: FolderRateLimiting

#if os(macOS)
    fileprivate struct TrashBucketKey: Hashable, Sendable {
        let shareID: String
        let parentID: String
    }

    private let deleteBatcherLock = NSLock()
    private var deleteBatcher: RequestBatcher<TrashBucketKey, String, Void>?
#endif

    public init(fileProviderManager: NSFileProviderManager,
                fileCreationProvider: @escaping CreateFilePerformerProvider,
                newRevisionUploadPerformProvider: @escaping NewRevisionUploadPerformerProvider,
                providersPipeline: DriveObservabilityPipeline = .legacy,
                folderRateLimiter: FolderRateLimiting = NoOpFolderRateLimiter()) {
        self.fileProviderManager = fileProviderManager
        self.fileCreationProvider = fileCreationProvider
        self.newRevisionUploadPerformerProvider = newRevisionUploadPerformProvider
        self.providersPipeline = providersPipeline
        self.folderRateLimiter = folderRateLimiter
        Log.info("ItemActionsOutlet init: \(instanceIdentifier.uuidString)", domain: .syncing)
    }

    deinit {
        Log.info("ItemActionsOutlet deinit: \(instanceIdentifier.uuidString)", domain: .syncing)
    }

    public func deleteItem(tower: Tower,
                           identifier: NSFileProviderItemIdentifier,
                           baseVersion version: NSFileProviderItemVersion,
                           options: NSFileProviderDeleteItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           progress: Progress?,
                           pool: AsyncManagedObjectContextPool) async throws
    {
        Log.info("Delete item \(identifier)", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(identifier) else {
            Log.info("Failed to delete item: node ID is invalid \(identifier)", domain: .fileProvider)
            throw Errors.nodeIdentifierNotFound(identifier: identifier)
        }
        let itemTemplate = ItemTemplate(itemIdentifier: identifier)

        do {
#if os(iOS)
            try await pool.withContext { moc in
                if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .delete(version: version), fields: [], contentsURL: nil, progress: progress, moc: moc) {
                    throw Errors.deletionRejected(updatedItem: resolvedItem)
                }
                try await tower.delete(nodeID: nodeID, moc: moc)
            }
#else
            try await deleteItemForMacOS(pool, tower, itemTemplate, version, progress, identifier, nodeID)
#endif
        } catch Errors.itemDeleted {
            return // item already deleted remotely
        } catch Errors.itemTrashed {
            // It shouldn't normally be possible to delete a trashed item,
            // but if it happens, the user may have attempted to delete the item
            // from within trash or restore it.
            // In case it's the later though, this will allow the untrash to
            // "work" by forcing a download of the contents before creating anew.
            // In case of the former, nothing will happen (item will still be
            // deleted locally though).
#if os(macOS)
            if #available(macOS 13, *) {
                try await fileProviderManager.signalErrorResolved(NSFileProviderError(.excludedFromSync))
            } else {
                try await fileProviderManager.signalErrorResolved(NSFileProviderError(.cannotSynchronize))
            }
#endif
            return
        }
    }

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil,
                           progress: Progress?,
                           moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        #if os(macOS)
        let mayAlreadyExist = options?.contains(.mayAlreadyExist) ?? false
        #else
        let mayAlreadyExist = false
        Log.info("Modify item \(item.itemIdentifier) fields \(changedFields) mayAlreadyExist \(mayAlreadyExist)", domain: .fileProvider)
        #endif
        if newContents != nil {
            Log.info("New cleartext content available", domain: .fileProvider)
        }

        guard let progressFunction = try await progressWithFunction(tower: tower, item: item, baseVersion: version, changedFields: changedFields, contents: newContents, progress: progress, moc: moc) else {
            // If none of the above cases could be handled, then we either couldn't
            // find the node in our DB or we don't handle any of the change fields
            Log.info("Irrelevant changes", domain: .fileProvider)
            guard let node = await tower.node(itemIdentifier: item.itemIdentifier, in: moc) else {
                Log.error("Can't find item's node in metadata DB, expect item to be removed by system on next enumeration", error: nil, domain: .fileProvider)
                throw Errors.nodeNotFound(identifier: item.itemIdentifier)
            }
            return (try NodeItem(node: node), [], false)
        }

        return try await progressFunction(tower, item, version, changedFields, newContents, progress, moc)
    }

    @discardableResult
    public func createItem(tower: Tower,
                           basedOn itemTemplate: NSFileProviderItem,
                           fields: NSFileProviderItemFields = [],
                           contents url: URL?,
                           options: NSFileProviderCreateItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           filename: String? = nil,
                           progress: Progress?,
                           moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Create item \(itemTemplate.itemIdentifier) from cleartext content", domain: .fileProvider)

        if itemTemplate.parentItemIdentifier == .trashContainer { // file system is attempting to create item in trash
            throw Errors.excludeFromSync
        }

        if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .create, fields: fields, contentsURL: url, progress: progress, moc: moc) {
            return (resolvedItem, [], false)
        }

        guard let parent = await tower.parentFolder(of: itemTemplate, in: moc) else { throw Errors.parentNotFound(identifier: itemTemplate.parentItemIdentifier) }

        let parentIdentifier = await moc.perform { parent.identifierWithinManagedObjectContext }
        return try await folderRateLimiter.runOperation(parent: parentIdentifier, in: moc) {
            if itemTemplate.isFolder {
                Log.info("Item is a folder", domain: .fileProvider)

                let createdFolder = try await tower.createFolder(named: filename ?? itemTemplate.filename, under: parent, moc: moc)
                return (try NodeItem(node: createdFolder), [], false)
            } else {
                Log.info("Item is a file", domain: .fileProvider)
                guard tower.sessionVault.currentAddress() != nil else {
                    throw Errors.noAddressInTower
                }

                // Delete the draft if it already exists before creating a new one
                if let existingDraft = await tower.draft(for: itemTemplate, moc: moc) {
                    if let moc = existingDraft.moc {
                        moc.performAndWait {
                            moc.delete(existingDraft)
                            try? moc.saveIfNeeded()
                        }
                    }
                }

                // We do not support creating proton doc files from the macOS client.
                // If one is created in the filesystem (e.g. copy/pasted), then we
                // exclude it from sync.
                if itemTemplate.isProtonFile {
                    throw Errors.excludeFromSync
                }

                let file = try await fileCreationProvider().createFile(tower: tower, item: itemTemplate, with: url, under: parent, progress: progress, logOperation: true, moc: moc)

                return try await moc.perform {
                    (try NodeItem(node: file), [], false)
                }
            }
        }
    }
}

#if os(macOS)
// MARK: - Batching

extension ItemActionsOutlet {

    private func deleteItemForMacOS(
        _ pool: AsyncManagedObjectContextPool,
        _ tower: Tower,
        _ itemTemplate: ItemTemplate,
        _ version: NSFileProviderItemVersion,
        _ progress: Progress?,
        _ identifier: NSFileProviderItemIdentifier,
        _ nodeID: NodeIdentifier
    ) async throws {
        // Release the moc before the batched flush so it can't pin a pool
        // slot for the duration of the batch wait.
        let parentID: String = try await pool.withContext { moc in
            if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .delete(version: version), fields: [], contentsURL: nil, progress: progress, moc: moc) {
                throw Errors.deletionRejected(updatedItem: resolvedItem)
            }
            Log.info("Trashing item remotely, deleting locally...", domain: .fileProvider)

            guard let node = await tower.node(itemIdentifier: identifier, in: moc) else {
                Log.error("Node not found despite no conflict being found", domain: .fileProvider)
                assertionFailure("Missing node in DB must be identified as a conflict")
                throw Errors.nodeNotFound(identifier: identifier)
            }

            guard let nodeMoc = node.moc else { throw Node.noMOC() }

            return try nodeMoc.performAndWait {
                guard let parent = node.parentFolder else { throw Errors.parentNotFound(identifier: identifier) }
                return parent.id
            }
        }

        if tower.featureFlags.isEnabled(flag: .driveMacFileProviderBatchingDisabled) {
            try await pool.withContext { moc in
                try await tower.trash(shareID: nodeID.shareID, parentID: parentID, linkIDs: [nodeID.nodeID], moc: moc)
            }
        } else {
            // Lock-protected so concurrent first-time access can't construct two batchers.
            let deleteBatcher: RequestBatcher<TrashBucketKey, String, Void> = deleteBatcherLock.withLock {
                if let deleteBatcher = self.deleteBatcher {
                    return deleteBatcher
                }
                let deleteBatcher = RequestBatcher<TrashBucketKey, String, Void>(
                    maxBatchSize: CloudSlot.maxBatchSize,
                    maxLatency: .seconds(3)
                ) { [weak tower] linkIDs, key in
                    await Self.flushTrashBatch(linkIDs: linkIDs, key: key, tower: tower)
                }
                self.deleteBatcher = deleteBatcher
                return deleteBatcher
            }

            let key = TrashBucketKey(shareID: nodeID.shareID, parentID: parentID)
            let linkID = nodeID.nodeID
            // Don't hold a moc during the enqueue wait — the flush acquires its own.
            try await withTaskCancellationHandler {
                try await deleteBatcher.enqueue(item: linkID, key: key, id: linkID)
            } onCancel: {
                Task { await deleteBatcher.cancel(id: linkID, key: key) }
            }
        }
    }

    private static func flushTrashBatch(
        linkIDs: [String],
        key: TrashBucketKey,
        tower: Tower?
    ) async -> [String: Result<Void, Error>] {
        guard let tower else {
            Log.error("Trash batch flush dropped — tower deallocated", domain: .fileProvider)
            return Dictionary(uniqueKeysWithValues: linkIDs.map {
                ($0, .failure(NSFileProviderError(.serverUnreachable)))
            })
        }

        // If the kill switch was flipped while items waited, drain one at a time through legacy.
        guard !tower.featureFlags.isEnabled(flag: .driveMacFileProviderBatchingDisabled) else {
            return await flushTrashBatchOneAtATime(key, linkIDs, tower)
        }

        Log.info(
            "Flushing trash batch (share=\(key.shareID), parent=\(key.parentID), \(linkIDs.count) links)",
            domain: .fileProvider
        )
        do {
            try await tower.storage.backgroundContextPool.withContext { moc in
                try await tower.trash(
                    shareID: key.shareID,
                    parentID: key.parentID,
                    linkIDs: linkIDs,
                    moc: moc
                )
            }
            return Dictionary(uniqueKeysWithValues: linkIDs.map { ($0, .success(())) })
        } catch {
            Log.error("Trash batch flush failed", error: error, domain: .fileProvider)
            return Dictionary(uniqueKeysWithValues: linkIDs.map { ($0, .failure(error)) })
        }
    }

    private static func flushTrashBatchOneAtATime(
        _ key: ItemActionsOutlet.TrashBucketKey,
        _ linkIDs: [String],
        _ tower: Tower
    ) async -> [String: Result<Void, any Error>] {
        Log.info(
            "Trash batch flush degrading to legacy per-item (share=\(key.shareID), parent=\(key.parentID), \(linkIDs.count) links)",
            domain: .fileProvider
        )
        return await tower.storage.backgroundContextPool.withContext { moc in
            await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
                for linkID in linkIDs {
                    group.addTask {
                        do {
                            try await tower.trash(
                                shareID: key.shareID,
                                parentID: key.parentID,
                                linkIDs: [linkID],
                                moc: moc
                            )
                            return (linkID, .success(()))
                        } catch {
                            return (linkID, .failure(error))
                        }
                    }
                }
                var results: [String: Result<Void, Error>] = [:]
                for await (linkID, result) in group {
                    results[linkID] = result
                }
                return results
            }
        }
    }
}
#endif

extension ItemActionsOutlet {

    // MARK: - Actions on items
    // swiftlint:disable:next function_parameter_count
    private func progressWithFunction(
        tower: Tower,
        item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents: URL?,
        progress: Progress?,
        moc: NSManagedObjectContext
    ) async throws -> ProgressFunction? {
        if changedFields.contains(.parentItemIdentifier), item.parentItemIdentifier == .trashContainer { // trash
            return progressWithTrash
        }

        if changedFields.contains(.parentItemIdentifier),
           let node = await tower.node(itemIdentifier: item.itemIdentifier, in: moc),
           let moc = node.moc {
            var shouldProgressWithRestore = false
            await moc.perform {
                shouldProgressWithRestore = (node.state == .deleted || node.isTrashInheriting) && item.parentItemIdentifier != .trashContainer
            }
            if shouldProgressWithRestore { // restore from trash
                Log.info("Synced item with remote shouldn't be present in local trash", domain: .fileProvider)
                return progressWithRestore
            }
            if changedFields.contains(.filename) { // combined move + rename (e.g. Finder "Keep Both")
                return progressWithMoveAndRename
            }
            return progressWithMove
        }

        if changedFields.contains(.filename) {
            return progressWithRename
        }

        if changedFields.contains(.contents) { // upload new revision
            Log.info("Uploading new contents...", domain: .fileProvider)
            guard tower.sessionVault.currentAddress() != nil else {
                throw Errors.noAddressInTower
            }
            return await progressWithNewRevision(
                uploadNewRevision: newRevisionUploadPerformerProvider().uploadNewRevision(item:file:tower:copy:fileSize:pendingFields:progress:moc:)
            )
        }

        return nil // no function found to handle this situation
    }

    // swiftlint:disable:next function_parameter_count
    func progressWithTrash(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion,
                           changedFields: NSFileProviderItemFields,
                           contents: URL?,
                           progress: Progress?,
                           moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Trashing item...", domain: .fileProvider)

        #if os(iOS)
        guard let node = await tower.node(itemIdentifier: item.itemIdentifier, in: moc) else {
            throw Errors.nodeNotFound(identifier: item.itemIdentifier)
        }

        guard let moc = node.moc else {
            throw Node.noMOC()
        }

        let (volumeID, shareID, parentID, linkID, isLocalFile) = try moc.performAndWait {
            guard let parent = node.parentNode else { throw node.invalidState("Trashing node should not be a root node.") }
            return (node.volumeID, node.shareId, parent.id, node.id, node.isLocalFile)
        }

        if isLocalFile {
            try tower.trashLocalNode([TrashingNodeIdentifier(volumeID: volumeID, shareID: shareID, parentID: parentID, nodeID: linkID)])
        } else {
            try await tower.trash([TrashingNodeIdentifier(volumeID: volumeID, shareID: shareID, parentID: parentID, nodeID: linkID)])
        }
        let nodeItem = try NodeItem(node: node)
        return (nodeItem, [], false)
        #else
        do {
            // Can only use the .delete changeType because all trash conflicts are ignored (same as delete)
            if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .trash(version: version), fields: changedFields, contentsURL: contents, progress: progress, moc: moc) {
                return (updatedItem, [], false)
            } else {
                throw Errors.excludeFromSync
            }
        } catch Errors.itemDeleted {
            return (nil, [], false)
        }
        #endif
    }

    // swiftlint:disable:next function_parameter_count
    func progressWithRestore(tower: Tower,
                             item: NSFileProviderItem,
                             baseVersion version: NSFileProviderItemVersion,
                             changedFields: NSFileProviderItemFields,
                             contents: URL?,
                             progress: Progress?,
                             moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Restoring item (shouldn't be possible)...", domain: .fileProvider)
        throw Errors.excludeFromSync
    }

    // swiftlint:disable:next function_parameter_count
    func progressWithMove(tower: Tower,
                          item: NSFileProviderItem,
                          baseVersion version: NSFileProviderItemVersion,
                          changedFields: NSFileProviderItemFields,
                          contents: URL?,
                          progress: Progress?,
                          moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Moving item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeIdentifierNotFound(identifier: item.itemIdentifier)
        }
        guard let newParent = await tower.parentFolder(of: item, in: moc) else { throw Errors.parentNotFound(identifier: item.parentItemIdentifier) }

        var pendingFields = changedFields
        pendingFields.remove(.parentItemIdentifier)

        let destinationParent = await moc.perform { newParent.identifierWithinManagedObjectContext }
        return try await folderRateLimiter.runOperation(parent: destinationParent, in: moc) {
            if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .move(version: version), fields: changedFields, contentsURL: contents, progress: progress, moc: moc) {
                return (updatedItem, pendingFields, false)
            } else {
                let node = try await tower.move(nodeID: nodeID, under: newParent, moc: moc)
                return (try NodeItem(node: node), pendingFields, false)
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    func progressWithMoveAndRename(tower: Tower,
                                   item: NSFileProviderItem,
                                   baseVersion version: NSFileProviderItemVersion,
                                   changedFields: NSFileProviderItemFields,
                                   contents: URL?,
                                   progress: Progress?,
                                   moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Moving and renaming item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeIdentifierNotFound(identifier: item.itemIdentifier)
        }
        guard let newParent = await tower.parentFolder(of: item, in: moc) else {
            throw Errors.parentNotFound(identifier: item.parentItemIdentifier)
        }

        var pendingFields = changedFields
        pendingFields.remove(.parentItemIdentifier)
        pendingFields.remove(.filename)

        let destinationParent = await moc.perform { newParent.identifierWithinManagedObjectContext }
        return try await folderRateLimiter.runOperation(parent: destinationParent, in: moc) {
            if let updatedItem = try await findAndResolveConflictIfNeeded(
                tower: tower, item: item, changeType: .move(version: version),
                fields: changedFields, contentsURL: contents, progress: progress, moc: moc
            ) {
                return (updatedItem, pendingFields, false)
            }

            let newName = item.filename.removingProtonExtensionIfNecessary()
            let newMime = item.contentType?.preferredMIMEType

            // Capture state BEFORE mutating — we need the old MIME to decide whether
            // to fire a follow-up rename for BE MIME sync.
            guard let existingNode = await tower.node(itemIdentifier: item.itemIdentifier, in: moc),
                  let nodeMoc = existingNode.moc else {
                throw Errors.nodeNotFound(identifier: item.itemIdentifier)
            }
            let (currentParentID, oldMime): (NodeIdentifier?, String?) = nodeMoc.performAndWait {
                (existingNode.parentNode?.identifier, existingNode.mimeType)
            }

            // Same-parent edge case: tower.move silently drops withNewName when newParent == currentParent.
            // Delegate to rename, which carries MIME natively.
            if currentParentID == newParent.identifier {
                Log.warning("Combined move+rename received with unchanged parent — applying rename only", domain: .fileProvider)
                let node = try await tower.rename(node: nodeID, cleartextName: newName, mimeType: newMime, moc: moc)
                return (try NodeItem(node: node), pendingFields, false)
            }

            // Atomic move with rename — server gets parent + name.
            let node = try await tower.move(nodeID: nodeID, under: newParent, withNewName: newName, moc: moc)

            // MoveEntryEndpoint doesn't carry MIME; if the new MIME differs from the local DB
            // value captured before the move, push it via a follow-up rename (which updates both
            // server and local DB). Best-effort: log on failure, don't roll back the successful move.
            if let newMime, newMime != oldMime {
                do {
                    _ = try await tower.rename(node: nodeID, cleartextName: newName, mimeType: newMime, moc: moc)
                } catch {
                    Log.error("Follow-up rename to sync MIME failed; local and server MIME remain stale until next rename", error: error, domain: .fileProvider)
                }
            }

            return (try NodeItem(node: node), pendingFields, false)
        }
    }

    // swiftlint:disable:next function_parameter_count
    func progressWithRename(tower: Tower,
                            item: NSFileProviderItem,
                            baseVersion version: NSFileProviderItemVersion,
                            changedFields: NSFileProviderItemFields,
                            contents: URL?,
                            progress: Progress?,
                            moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Renaming item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeIdentifierNotFound(identifier: item.itemIdentifier)
        }
        guard await tower.parentFolder(of: item, in: moc) != nil else {
            throw Errors.parentNotFound(identifier: item.parentItemIdentifier)
        }

        var pendingFields = changedFields
        pendingFields.remove(.filename)

        // Check for conflicts
        let actionChangeType: ItemActionChangeType = changedFields.contains(.parentItemIdentifier) ? .move(version: version) : .modifyMetadata(version: version)
        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: actionChangeType, fields: changedFields, contentsURL: contents, progress: progress, moc: moc) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.rename(node: nodeID, cleartextName: item.filename.removingProtonExtensionIfNecessary(), moc: moc)
            return (try NodeItem(node: node), pendingFields, false)
        }
    }

    private func progressWithNewRevision(
        uploadNewRevision: @escaping (NSFileProviderItem, File, Tower, URL, Int, NSFileProviderItemFields, Progress?, NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    ) -> ProgressFunction {
        return { tower, item, version, changedFields, newContents, progress, moc in

            try abortIfCancelled(progress: progress)

            var pendingFields = changedFields
            pendingFields.remove(.contents)
            pendingFields.remove(.contentModificationDate)
            #if os(macOS)
            pendingFields.remove(.lastUsedDate)
            #endif

            if let updatedItem = try await self.findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .modifyContents(version: version, contents: newContents), fields: changedFields, contentsURL: newContents, progress: progress, moc: moc) {

                try abortIfCancelled(progress: progress)

                #if os(iOS)
                return (updatedItem, pendingFields, false)
                #else
                // Fetch content if the versions differ (as described in the code
                // comment of NSFileProviderReplicatedExtension's modifyItem
                // function.
                let shouldFetchContent = version.contentVersion != updatedItem.itemVersion?.contentVersion
                return (updatedItem, pendingFields, shouldFetchContent)
                #endif
            } else {

                try abortIfCancelled(progress: progress)

                guard let file = await tower.node(itemIdentifier: item.itemIdentifier, in: moc) as? File else {
                    Log.error("File not found despite no conflict being found", error: nil, domain: .fileProvider)
                    assertionFailure("Missing file in DB must be identified as a conflict")
                    throw Errors.nodeNotFound(identifier: item.itemIdentifier)
                }

                // fileCopy is the copy of the file that the system asked us to upload from the system-provided location
                // (~/Library/Application\ Support/FileProvider/{domain_id}/wharf/wharf/propagate) to the app's temporary directory
                // (obtained from FileManager.default.temporaryDirectory, see prepare(forUpload:from:))
                guard let newContents else {
                    try throwIfNotCancelled(progress: progress, error: Errors.urlForUploadIsNil)
                }
                guard let fileSize = newContents.fileSize else {
                    try throwIfNotCancelled(progress: progress, error: Errors.urlForUploadHasNoSize)
                }
                guard let fileCopy = try performIfNotCancelled(
                    progress: progress, { try ItemActionsOutlet.prepare(forUpload: item, from: newContents) }
                ) else {
                    try throwIfNotCancelled(progress: progress, error: Errors.urlForUploadFailedCopying)
                }

                defer { try? FileManager.default.removeItem(at: fileCopy.deletingLastPathComponent()) }

                return try await performIfNotCancelled(progress: progress, {
                    return try await uploadNewRevision(item, file, tower, fileCopy, fileSize, pendingFields, progress, moc)
                })
            }
        }
    }
}

extension ItemActionsOutlet {
    // swiftlint:disable:next function_parameter_count
    private func findAndResolveConflictIfNeeded(
        tower: Tower,
        item: NSFileProviderItem,
        changeType: ItemActionChangeType,
        fields: NSFileProviderItemFields,
        contentsURL: URL?,
        progress: Progress?,
        moc: NSManagedObjectContext
    ) async throws -> NSFileProviderItem?
    {
        #if os(iOS)
        return nil
        #else
        let itemWithNormalizedFilename = NodeItem(item: item, filename: item.filename.removingProtonExtensionIfNecessary())

        guard let (action, conflictingNode) = try await identifyConflict(tower: tower, basedOn: itemWithNormalizedFilename, changeType: changeType, fields: fields, moc: moc) else {
            Log.info("No conflict identified", domain: .fileProvider)
            return nil // no conflict found
        }

        Log.info("Conflict identified: \(action)", domain: .fileProvider)
        return try await resolveConflict(
            tower: tower, between: itemWithNormalizedFilename, with: contentsURL, and: conflictingNode, applying: action, fields: fields, progress: progress, moc: moc
        )
        #endif
    }
}

extension ItemActionsOutlet {
    public static func prepare(forUpload itemTemplate: NSFileProviderItem, from url: URL?) throws -> URL? {
        guard let url = url else { return nil }
        // copy file from system temporary location to app temporary location so it will have correct mime and name
        // TODO: inject mime and name directly into Uploader
        let parentFolderUUID = getUUIDParentDirectory(url)
        let copyParent = FileManager.default.temporaryDirectory.appendingPathComponent("Clear/\(parentFolderUUID)")
        let copy = copyParent.appendingPathComponent(itemTemplate.filename)
        try? FileManager.default.removeItem(atPath: copyParent.path) // best effort
        try FileManager.default.createDirectory(at: copyParent, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }

    static func getUUIDParentDirectory(_ url: URL) -> String {
        let parentFolderUUID = url.deletingLastPathComponent().lastPathComponent
        if let uuid = UUID(uuidString: parentFolderUUID) {
            return uuid.uuidString
        } else {
            return UUID().uuidString
        }
    }
}

#if os(iOS)
public final class DefaultCreateFilePerformer: CreateFilePerformer {

    public init() {}

    // swiftlint:disable:next function_parameter_count
    public func createFile(tower: Tower,
                           item: NSFileProviderItem,
                           with url: URL?,
                           under parent: Folder,
                           progress: Progress?,
                           logOperation _: Bool,
                           moc: NSManagedObjectContext) async throws -> Node {

        guard let url else {
            throw Errors.urlForUploadIsNil
        }
        
        guard let fileSize = url.fileSize else {
            throw Errors.urlForUploadHasNoSize
        }
        
        guard let copy = try? ItemActionsOutlet.prepare(forUpload: item, from: url) else {
            throw Errors.urlForUploadFailedCopying
        }
        
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        
        let draft = try tower.fileImporter.importFile(from: copy, to: parent, with: item.itemIdentifier.rawValue)
        guard fileSize == copy.fileSize else {
            try await tower.fpSDKObjects.fileUploader.deleteUploadingFile(identifier: draft.genericIdentifier)
            throw URLConsistencyError.urlSizeMismatch
        }
        do {
            let fileIdentifier: AnyVolumeIdentifier
            #if os(iOS)
            fileIdentifier = try await tower.fpSDKObjects.fileUploader.upload(identifier: draft.identifier.any(), duplicateAction: .keepBoth)
            #else
            fatalError("Mac shouldn't use this function")
            fileIdentifier = try await tower.fpSDKObjects.fileUploader.upload(identifier: draft.identifier.any())
            #endif
            let uploadedFile: File = try File.fetchOrThrow(identifier: fileIdentifier, in: moc)
            return uploadedFile
        } catch {
            throw error
        }
    }
}

public final class DefaultNewRevisionUploadPerformer: NewRevisionUploadPerformer {

    public init() {}

    // swiftlint:disable:next function_parameter_count
    public func uploadNewRevision(
        item: NSFileProviderItem,
        file: File,
        tower: Tower,
        copy: URL,
        fileSize: Int,
        pendingFields: NSFileProviderItemFields,
        progress: Progress?,
        moc: NSManagedObjectContext
    ) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool) {
        if file.uploadIDIfUploadingNewRevision() != nil {
            await tower.fpSDKObjects.fileUploader.cancel(identifier: file.genericIdentifier)
            file.prepareForNewUpload()
        }
        
        let fileWithNewRevision = try tower.revisionImporter.importNewRevision(from: copy, into: file)
        guard fileSize == copy.fileSize else {
            throw URLConsistencyError.urlSizeMismatch
        }
        
        // TODO: add progress reporting here, maybe by using SuspendableFileUploader instead of tower.fileUploader?
        let uploadedIdentifier = try await tower.fpSDKObjects.fileUploader.upload(identifier: file.genericIdentifier)
        let fileWithUploadedRevision = try await moc.perform { [moc] in
            let node: Node = try Node.fetchOrThrow(identifier: uploadedIdentifier, allowSubclasses: true, in: moc)
            return node
        }
        return (try NodeItem(node: fileWithUploadedRevision), pendingFields, false)
    }
}

#endif
