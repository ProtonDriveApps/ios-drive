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

public final class ItemActionsOutlet {
    public typealias SuccessfulCompletion = (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    public typealias Completion = (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void

    private let fileProviderManager: NSFileProviderManager
    
    private let instanceIdentifier = UUID()

    public init(fileProviderManager: NSFileProviderManager) {
        self.fileProviderManager = fileProviderManager
        Log.info("ItemActionsOutlet init: \(instanceIdentifier.uuidString)", domain: .syncing)
    }
    
    deinit {
        Log.info("ItemActionsOutlet deinit: \(instanceIdentifier.uuidString)", domain: .syncing)
    }
    
    public func deleteItem(tower: Tower,
                           identifier: NSFileProviderItemIdentifier,
                           baseVersion version: NSFileProviderItemVersion,
                           options: NSFileProviderDeleteItemOptions = [],
                           request: NSFileProviderRequest? = nil) async throws
    {
        Log.info("Delete item \(identifier)", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(identifier) else {
            Log.info("Failed to delete item: node ID is invalid \(identifier)", domain: .fileProvider)
            throw Errors.nodeNotFound
        }
        let itemTemplate = ItemTemplate(itemIdentifier: identifier)

        do {
            if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .delete(version: version), fields: [], contentsURL: nil) {
                throw Errors.deletionRejected(updatedItem: resolvedItem)
            } else {
                #if os(iOS)
                try await tower.delete(nodeID: nodeID)
                #else
                Log.info("Trashing item remotely, deleting locally...", domain: .fileProvider)

                guard let node = tower.node(itemIdentifier: identifier) else {
                    Log.error("Node not found despite no conflict being found", domain: .fileProvider)
                    assertionFailure("Missing node in DB must be identified as a conflict")
                    throw Errors.nodeNotFound
                }

                guard let moc = node.moc else { throw Node.noMOC() }

                let parentID = try moc.performAndWait {
                    guard let parent = node.parentLink else { throw Errors.parentNotFound }
                    return parent.id
                }

                try await tower.trash(shareID: nodeID.shareID, parentID: parentID, linkIDs: [nodeID.nodeID])
                #endif
            }
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
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil,
                           changeObserver: SyncChangeObserver? = nil) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Modify item \(item.itemIdentifier) fields \(changedFields))", domain: .fileProvider)
        if newContents != nil {
            Log.info("New cleartext content available at path \(newContents?.path ?? "-")", domain: .fileProvider)
        }

        guard let progressFunction = try await progressWithFunction(tower: tower, item: item, baseVersion: version, changedFields: changedFields, contents: newContents) else {
            // If none of the above cases could be handled, then we either couldn't
            // find the node in our DB or we don't handle any of the change fields
            Log.info("Irrelevant changes", domain: .fileProvider)
            guard let node = tower.node(itemIdentifier: item.itemIdentifier) else {
                Log.error("Can't find item's node in metadata DB, expect item to be removed by system on next enumeration", domain: .fileProvider)
                throw Errors.nodeNotFound
            }
            return (try NodeItem(node: node), [], false)
        }

        changeObserver?.incrementSyncCounter()
        do {
            let result = try await progressFunction(tower, item, version, changedFields, newContents)
            changeObserver?.decrementSyncCounter(type: .push, error: nil)
            return result
        } catch {
            changeObserver?.decrementSyncCounter(type: .push, error: error)
            throw error
        }
    }
    
    @discardableResult
    public func createItem(tower: Tower,
                           basedOn itemTemplate: NSFileProviderItem,
                           fields: NSFileProviderItemFields = [],
                           contents url: URL?,
                           options: NSFileProviderCreateItemOptions = [],
                           request: NSFileProviderRequest? = nil) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Create item \(itemTemplate.itemIdentifier) from cleartext content at path \(url?.path ?? "unknown")", domain: .fileProvider)

        if itemTemplate.parentItemIdentifier == .trashContainer { // file system is attempting to create item in trash
            throw Errors.excludeFromSync
        }

        if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .create, fields: fields, contentsURL: url) {
            return (resolvedItem, [], false)
        }

        guard let parent = tower.parentFolder(of: itemTemplate) else { throw Errors.parentNotFound }
        try checkFolderLimit(for: parent, storage: tower.storage)

        if itemTemplate.isFolder {
            Log.info("Item is a folder", domain: .fileProvider)

            let createdFolder = try await tower.createFolder(named: itemTemplate.filename, under: parent)
            return (try NodeItem(node: createdFolder), [], false)
        } else {
            Log.info("Item is a file", domain: .fileProvider)
            guard tower.sessionVault.currentAddress() != nil else {
                throw Errors.noAddressInTower
            }

            // Delete the draft if it already exists before creating a new one
            if let existingDraft = tower.draft(for: itemTemplate) {
                existingDraft.delete()
            }
            
            // we cannot create the proton docs file from macos client, so we exclude from sync
            if itemTemplate.contentType?.identifier == ProtonDocumentConstants.uti {
                throw Errors.excludeFromSync
            }

            let file = try await createFile(tower: tower, item: itemTemplate, with: url, under: parent)
            
            return (try NodeItem(node: file), [], false)
        }
    }

    // MARK: - Actions on items

    private func progressWithFunction(tower: Tower,
                                      item: NSFileProviderItem,
                                      baseVersion version: NSFileProviderItemVersion,
                                      changedFields: NSFileProviderItemFields,
                                      contents: URL?) async throws -> ((_ tower: Tower,
                                                                                            _ item: NSFileProviderItem,
                                                                                            _ version: NSFileProviderItemVersion,
                                                                                            _ changedFields: NSFileProviderItemFields,
                                                                                            _ contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool))? {
        if changedFields.contains(.parentItemIdentifier), item.parentItemIdentifier == .trashContainer { // trash
            return progressWithTrash
        }

        if changedFields.contains(.parentItemIdentifier), let node = tower.node(itemIdentifier: item.itemIdentifier), let moc = node.moc {
            var shouldProgressWithRestore = false
            await moc.perform {
                shouldProgressWithRestore = (node.state == .deleted || node.isTrashInheriting) && item.parentItemIdentifier != .trashContainer
            }
            if shouldProgressWithRestore { // restore from trash
                Log.info("Synced item with remote shouldn't be present in local trash", domain: .fileProvider)
                return progressWithRestore
            } else { // move
                return progressWithMove
            }
        }

        if changedFields.contains(.filename) {
            return progressWithRename
        }

        if changedFields.contains(.contents) { // upload new revision
            Log.info("Uploading new contents...", domain: .fileProvider)
            guard tower.sessionVault.currentAddress() != nil else {
                throw Errors.noAddressInTower
            }

            return progressWithNewRevision
        }

        return nil // no function found to handle this situation
    }

    func progressWithTrash(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion,
                           changedFields: NSFileProviderItemFields,
                           contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Trashing item...", domain: .fileProvider)

        #if os(iOS)
        guard let node = tower.node(itemIdentifier: item.itemIdentifier) else {
            throw Errors.nodeNotFound
        }

        guard let moc = node.moc else {
            throw Node.noMOC()
        }

        let (shareID, parentID, linkID, isLocalFile) = try moc.performAndWait {
            guard let parent = node.parentLink else { throw node.invalidState("Trashing node should not be a root node.") }
            return (node.shareID, parent.id, node.id, node.isLocalFile)
        }

        if isLocalFile {
            tower.trashLocalNode([node.id])
        } else {
            try await tower.trash(shareID: shareID, parentID: parentID, linkIDs: [linkID])
        }
        let nodeItem = try NodeItem(node: node)
        return (nodeItem, [], false)
        #else
        do {
            // Can only use the .delete changeType because all trash conflicts are ignored (same as delete)
            if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .trash(version: version), fields: changedFields, contentsURL: contents) {
                return (updatedItem, [], false)
            } else {
                throw Errors.excludeFromSync
            }
        } catch Errors.itemDeleted {
            return (nil, [], false)
        }
        #endif
    }

    func progressWithRestore(tower: Tower,
                             item: NSFileProviderItem,
                             baseVersion version: NSFileProviderItemVersion,
                             changedFields: NSFileProviderItemFields,
                             contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Restoring item (shouldn't be possible)...", domain: .fileProvider)
        throw Errors.excludeFromSync
    }

    func progressWithMove(tower: Tower,
                          item: NSFileProviderItem,
                          baseVersion version: NSFileProviderItemVersion,
                          changedFields: NSFileProviderItemFields,
                          contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Moving item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeNotFound
        }
        guard let newParent = tower.parentFolder(of: item) else { throw Errors.parentNotFound }
        try checkFolderLimit(for: newParent, storage: tower.storage)

        var pendingFields = changedFields
        pendingFields.remove(.parentItemIdentifier)

        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .move(version: version), fields: changedFields, contentsURL: contents) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.move(nodeID: nodeID, under: newParent)
            return (try NodeItem(node: node), pendingFields, false)
        }
    }

    func progressWithRename(tower: Tower,
                            item: NSFileProviderItem,
                            baseVersion version: NSFileProviderItemVersion,
                            changedFields: NSFileProviderItemFields,
                            contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Renaming item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeNotFound
        }
        guard tower.parentFolder(of: item) != nil else {
            throw Errors.parentNotFound
        }

        var pendingFields = changedFields
        pendingFields.remove(.filename)

        // Check for conflicts
        let actionChangeType: ItemActionChangeType = changedFields.contains(.parentItemIdentifier) ? .move(version: version) : .modifyMetadata(version: version)
        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: actionChangeType, fields: changedFields, contentsURL: contents) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.rename(node: nodeID, cleartextName: item.filename.filenameNormalizedForRemote())
            return (try NodeItem(node: node), pendingFields, false)
        }
    }

    func progressWithNewRevision(tower: Tower,
                                 item: NSFileProviderItem,
                                 baseVersion version: NSFileProviderItemVersion,
                                 changedFields: NSFileProviderItemFields,
                                 newContents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        var pendingFields = changedFields
        pendingFields.remove(.contents)
        pendingFields.remove(.contentModificationDate)
        #if os(macOS)
        pendingFields.remove(.lastUsedDate)
        #endif
        
        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .modifyContents(version: version, contents: newContents), fields: changedFields, contentsURL: newContents) {

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
            guard let file = tower.node(itemIdentifier: item.itemIdentifier) as? File else {
                Log.error("File not found despite no conflict being found", domain: .fileProvider)
                assertionFailure("Missing file in DB must be identified as a conflict")
                throw Errors.nodeNotFound
            }
            guard let fileSize = newContents?.fileSize, let copy = self.prepare(forUpload: item, from: newContents) else {
                throw Errors.emptyUrlForFileUpload
            }

            defer {
                try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
            }

            if let uploadID = file.uploadIDIfUploadingNewRevision() {
                tower.fileUploader.cancelOperation(id: uploadID)
                file.prepareForNewUpload()
            }

            let fileWithNewRevision = try tower.revisionImporter.importNewRevision(from: copy, into: file)
            guard fileSize == copy.fileSize else {
                throw URLConsistencyError.urlSizeMismatch
            }

            let fileWithUploadedRevision = try await tower.fileUploader.upload(fileWithNewRevision)
            return (try NodeItem(node: fileWithUploadedRevision), pendingFields, false)
        }
    }

}

extension ItemActionsOutlet {
    private func findAndResolveConflictIfNeeded(
        tower: Tower,
        item: NSFileProviderItem,
        changeType: ItemActionChangeType,
        fields: NSFileProviderItemFields,
        contentsURL: URL?) async throws -> NSFileProviderItem?
    {
        #if os(iOS)
        return nil
        #else
        let itemWithNormalizedFilename = NodeItem(item: item, filename: item.filename.filenameNormalizedForRemote())

        guard let (action, conflictingNode) = try identifyConflict(tower: tower, basedOn: itemWithNormalizedFilename, changeType: changeType, fields: fields) else {
            Log.info("No conflict identified", domain: .fileProvider)
            return nil // no conflict found
        }

        Log.info("Conflict identified: \(action)", domain: .fileProvider)
        return try await resolveConflict(tower: tower, between: itemWithNormalizedFilename, with: contentsURL, and: conflictingNode, applying: action)
        #endif
    }

    private func checkFolderLimit(for parent: Folder, storage: StorageManager) throws {
        guard let moc = parent.moc else { throw Folder.noMOC() }
        try moc.performAndWait {
            guard try storage.fetchEntireChildCount(of: parent.id, share: parent.shareID, moc: moc) <= Constants.maxChildrenInFolder else {
                throw Errors.childLimitReached
            }
        }
    }
}

extension ItemActionsOutlet {
    func createFile(tower: Tower, item: NSFileProviderItem, with url: URL?, under parent: Folder) async throws -> File {
        guard let fileSize = url?.fileSize, let copy = self.prepare(forUpload: item, from: url) else {
            throw Errors.emptyUrlForFileUpload
        }

        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }

        let draft = try tower.fileImporter.importFile(from: copy, to: parent, with: item.itemIdentifier.rawValue)
        guard fileSize == copy.fileSize else {
            tower.fileUploader.deleteUploadingFile(draft)
            throw URLConsistencyError.urlSizeMismatch
        }

        #if os(iOS)
        do {
            return try await tower.fileUploader.upload(draft)
        } catch {
            tower.fileUploader.deleteUploadingFile(draft)
            throw error
        }
        #else
        let fileUploader = SuspendableFileUploader(uploader: tower.fileUploader)
        do {
            return try await fileUploader.upload(draft)
        } catch {
            fileUploader.deleteUploadingFile(draft)
            throw error
        }
        #endif
    }

    private func prepare(forUpload itemTemplate: NSFileProviderItem, from url: URL?) -> URL? {
        guard let url = url else { return nil }
        // copy file from system temporary location to app temporary location so it will have correct mime and name
        // TODO: inject mime and name directly into Uploader
        let parentFolderUUID = getUUIDParentDirectory(url)
        let copyParent = FileManager.default.temporaryDirectory.appendingPathComponent("Clear/\(parentFolderUUID)")
        let copy = copyParent.appendingPathComponent(itemTemplate.filename)
        try? FileManager.default.removeItem(atPath: copyParent.path)
        try? FileManager.default.createDirectory(at: copyParent, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.copyItem(at: url, to: copy)
        return copy
    }

    func getUUIDParentDirectory(_ url: URL) -> String {
        let parentFolderUUID = url.deletingLastPathComponent().lastPathComponent
        if let uuid = UUID(uuidString: parentFolderUUID) {
            return uuid.uuidString
        } else {
            return UUID().uuidString
        }
    }
}
