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
    func createFile(tower: Tower,
                    item: NSFileProviderItem,
                    with contents: URL?,
                    under parent: Folder,
                    progress: Progress?,
                    logOperation: Bool) async throws -> (Node, NSManagedObjectContext)
}

public typealias NewRevisionUploadPerformerProvider = () async -> NewRevisionUploadPerformer

public protocol NewRevisionUploadPerformer {
    // swiftlint:disable:next function_parameter_count
    func uploadNewRevision(item: NSFileProviderItem, file: File, tower: Tower, copy: URL, fileSize: Int, pendingFields: NSFileProviderItemFields, progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
}

public final class ItemActionsOutlet {
    public typealias SuccessfulCompletion = (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    public typealias Completion = (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private typealias ProgressFunction = (Tower, NSFileProviderItem, NSFileProviderItemVersion, NSFileProviderItemFields, URL?, Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)

    private let fileProviderManager: NSFileProviderManager
    private let instanceIdentifier = UUID()
    let fileCreationProvider: CreateFilePerformerProvider
    let newRevisionUploadPerformerProvider: NewRevisionUploadPerformerProvider

    public init(fileProviderManager: NSFileProviderManager,
                fileCreationProvider: @escaping CreateFilePerformerProvider = { DefaultCreateFilePerformer() },
                newRevisionUploadPerformProvider: @escaping NewRevisionUploadPerformerProvider = { DefaultNewRevisionUploadPerformer() }) {
        self.fileProviderManager = fileProviderManager
        self.fileCreationProvider = fileCreationProvider
        self.newRevisionUploadPerformerProvider = newRevisionUploadPerformProvider
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
                           progress: Progress?) async throws
    {
        Log.info("Delete item \(identifier)", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(identifier) else {
            Log.info("Failed to delete item: node ID is invalid \(identifier)", domain: .fileProvider)
            throw Errors.nodeIdentifierNotFound
        }
        let itemTemplate = ItemTemplate(itemIdentifier: identifier)

        do {
            if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .delete(version: version), fields: [], contentsURL: nil, progress: progress) {
                throw Errors.deletionRejected(updatedItem: resolvedItem)
            } else {
                #if os(iOS)
                try await tower.delete(nodeID: nodeID)
                #else
                Log.info("Trashing item remotely, deleting locally...", domain: .fileProvider)

                guard let node = await tower.node(itemIdentifier: identifier) else {
                    Log.error("Node not found despite no conflict being found", domain: .fileProvider)
                    assertionFailure("Missing node in DB must be identified as a conflict")
                    throw Errors.nodeNotFound
                }

                guard let moc = node.moc else { throw Node.noMOC() }

                let parentID = try moc.performAndWait {
                    guard let parent = node.parentFolder else { throw Errors.parentNotFound }
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
    // swiftlint:disable:next function_parameter_count
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil,
                           progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        #if os(macOS)
        let mayAlreadyExist = options?.contains(.mayAlreadyExist) ?? false
        #else
        let mayAlreadyExist = false
        #endif
        Log.info("Modify item \(item.itemIdentifier) fields \(changedFields) mayAlreadyExist \(mayAlreadyExist)", domain: .fileProvider)
        if newContents != nil {
            Log.info("New cleartext content available at path \(newContents?.path ?? "-")", domain: .fileProvider)
        }

        guard let progressFunction = try await progressWithFunction(tower: tower, item: item, baseVersion: version, changedFields: changedFields, contents: newContents, progress: progress) else {
            // If none of the above cases could be handled, then we either couldn't
            // find the node in our DB or we don't handle any of the change fields
            Log.info("Irrelevant changes", domain: .fileProvider)
            guard let node = await tower.node(itemIdentifier: item.itemIdentifier) else {
                Log.error("Can't find item's node in metadata DB, expect item to be removed by system on next enumeration", error: nil, domain: .fileProvider)
                throw Errors.nodeNotFound
            }
            return (try NodeItem(node: node), [], false)
        }

        return try await progressFunction(tower, item, version, changedFields, newContents, progress)
    }
    
    @discardableResult
    public func createItem(tower: Tower,
                           basedOn itemTemplate: NSFileProviderItem,
                           fields: NSFileProviderItemFields = [],
                           contents url: URL?,
                           options: NSFileProviderCreateItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Create item \(itemTemplate.itemIdentifier) from cleartext content at path \(url?.path ?? "unknown")", domain: .fileProvider)

        if itemTemplate.parentItemIdentifier == .trashContainer { // file system is attempting to create item in trash
            throw Errors.excludeFromSync
        }

        if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .create, fields: fields, contentsURL: url, progress: progress) {
            return (resolvedItem, [], false)
        }

        guard let parent = await tower.parentFolder(of: itemTemplate) else { throw Errors.parentNotFound }
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
            if let existingDraft = await tower.draft(for: itemTemplate) {
                existingDraft.delete()
            }
            
            // We do not support creating proton doc files from the macOS client.
            // If one is created in the filesystem (e.g. copy/pasted), then we
            // exclude it from sync.
            if itemTemplate.isProtonFile {
                throw Errors.excludeFromSync
            }

            let (file, context) = try await fileCreationProvider().createFile(tower: tower, item: itemTemplate, with: url, under: parent, progress: progress, logOperation: true)

            return try await context.perform {
                (try NodeItem(node: file), [], false)
            }
        }
    }

    // MARK: - Actions on items
    // swiftlint:disable:next function_parameter_count
    private func progressWithFunction(
        tower: Tower,
        item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents: URL?,
        progress: Progress?
    ) async throws -> ProgressFunction? {
        if changedFields.contains(.parentItemIdentifier), item.parentItemIdentifier == .trashContainer { // trash
            return progressWithTrash
        }

        if changedFields.contains(.parentItemIdentifier),
           let node = await tower.node(itemIdentifier: item.itemIdentifier),
           let moc = node.moc {
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
            return await progressWithNewRevision(
                uploadNewRevision: newRevisionUploadPerformerProvider().uploadNewRevision(item:file:tower:copy:fileSize:pendingFields:progress:)
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
                           progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Trashing item...", domain: .fileProvider)

        #if os(iOS)
        guard let node = await tower.node(itemIdentifier: item.itemIdentifier) else {
            throw Errors.nodeNotFound
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
            if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .trash(version: version), fields: changedFields, contentsURL: contents, progress: progress) {
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
                             progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
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
                          progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Moving item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeIdentifierNotFound
        }
        guard let newParent = await tower.parentFolder(of: item) else { throw Errors.parentNotFound }
        try checkFolderLimit(for: newParent, storage: tower.storage)

        var pendingFields = changedFields
        pendingFields.remove(.parentItemIdentifier)

        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .move(version: version), fields: changedFields, contentsURL: contents, progress: progress) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.move(nodeID: nodeID, under: newParent)
            return (try NodeItem(node: node), pendingFields, false)
        }
    }

    // swiftlint:disable:next function_parameter_count
    func progressWithRename(tower: Tower,
                            item: NSFileProviderItem,
                            baseVersion version: NSFileProviderItemVersion,
                            changedFields: NSFileProviderItemFields,
                            contents: URL?,
                            progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        Log.info("Renaming item...", domain: .fileProvider)
        guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
            throw Errors.nodeIdentifierNotFound
        }
        guard await tower.parentFolder(of: item) != nil else {
            throw Errors.parentNotFound
        }

        var pendingFields = changedFields
        pendingFields.remove(.filename)

        // Check for conflicts
        let actionChangeType: ItemActionChangeType = changedFields.contains(.parentItemIdentifier) ? .move(version: version) : .modifyMetadata(version: version)
        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: actionChangeType, fields: changedFields, contentsURL: contents, progress: progress) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.rename(node: nodeID, cleartextName: item.filename.removingProtonExtensionIfNecessary())
            return (try NodeItem(node: node), pendingFields, false)
        }
    }

    private func progressWithNewRevision(
        uploadNewRevision: @escaping (NSFileProviderItem, File, Tower, URL, Int, NSFileProviderItemFields, Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    ) -> ProgressFunction {
        return { tower, item, version, changedFields, newContents, progress in
            
            try abortIfCancelled(progress: progress)

            var pendingFields = changedFields
            pendingFields.remove(.contents)
            pendingFields.remove(.contentModificationDate)
            #if os(macOS)
            pendingFields.remove(.lastUsedDate)
            #endif
            
            if let updatedItem = try await self.findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .modifyContents(version: version, contents: newContents), fields: changedFields, contentsURL: newContents, progress: progress) {

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

                guard let file = await tower.node(itemIdentifier: item.itemIdentifier) as? File else {
                    Log.error("File not found despite no conflict being found", error: nil, domain: .fileProvider)
                    assertionFailure("Missing file in DB must be identified as a conflict")
                    throw Errors.nodeNotFound
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
                    return try await uploadNewRevision(item, file, tower, fileCopy, fileSize, pendingFields, progress)
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
        progress: Progress?) async throws -> NSFileProviderItem?
    {
        #if os(iOS)
        return nil
        #else
        let itemWithNormalizedFilename = NodeItem(item: item, filename: item.filename.removingProtonExtensionIfNecessary())

        guard let (action, conflictingNode) = try await identifyConflict(tower: tower, basedOn: itemWithNormalizedFilename, changeType: changeType, fields: fields) else {
            Log.info("No conflict identified", domain: .fileProvider)
            return nil // no conflict found
        }

        Log.info("Conflict identified: \(action)", domain: .fileProvider)
        return try await resolveConflict(
            tower: tower, between: itemWithNormalizedFilename, with: contentsURL, and: conflictingNode, applying: action, fields: fields, progress: progress
        )
        #endif
    }

    private func checkFolderLimit(for parent: Folder, storage: StorageManager) throws {
        guard let moc = parent.moc else { throw Folder.noMOC() }
        try moc.performAndWait {
            guard try storage.fetchEntireChildCount(of: parent.id, share: parent.shareId, moc: moc) <= Constants.maxChildrenInFolder else {
                throw Errors.childLimitReached
            }
        }
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

public final class DefaultCreateFilePerformer: CreateFilePerformer {

    public init() {}

    public func createFile(tower: Tower, 
                           item: NSFileProviderItem,
                           with url: URL?,
                           under parent: Folder,
                           progress: Progress?,
                           logOperation _: Bool) async throws -> (Node, NSManagedObjectContext) {

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
            tower.fileUploader.deleteUploadingFile(draft, error: .accessFileFailed)
            throw URLConsistencyError.urlSizeMismatch
        }

        #if os(iOS)
        do {
            return (try await tower.fileUploader.upload(draft), tower.fileUploader.moc)
        } catch {
            tower.fileUploader.deleteUploadingFile(draft, error: nil)
            throw error
        }
        #else
        let fileUploader = SuspendableFileUploader(uploader: tower.fileUploader, progress: progress)
        do {
            return (try await fileUploader.upload(draft), tower.fileUploader.moc)
        } catch {
            fileUploader.deleteUploadingFile(draft)
            throw error
        }
        #endif
    }
}

public final class DefaultNewRevisionUploadPerformer: NewRevisionUploadPerformer {
    
    public init() {}
    
    // swiftlint:disable:next function_parameter_count
    public func uploadNewRevision(item: NSFileProviderItem, file: File, tower: Tower, copy: URL, fileSize: Int, pendingFields: NSFileProviderItemFields, progress: Progress?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool) {
        if let uploadID = file.uploadIDIfUploadingNewRevision() {
            tower.fileUploader.cancelOperation(id: uploadID)
            file.prepareForNewUpload()
        }

        let fileWithNewRevision = try tower.revisionImporter.importNewRevision(from: copy, into: file)
        guard fileSize == copy.fileSize else {
            throw URLConsistencyError.urlSizeMismatch
        }

        // TODO: add progress reporting here, maybe by using SuspendableFileUploader instead of tower.fileUploader?
        let fileWithUploadedRevision = try await tower.fileUploader.upload(fileWithNewRevision)
        return (try NodeItem(node: fileWithUploadedRevision), pendingFields, false)
    }
}
