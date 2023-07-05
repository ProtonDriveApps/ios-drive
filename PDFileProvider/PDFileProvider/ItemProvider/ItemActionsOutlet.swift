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
import os.log

public final class ItemActionsOutlet: LogObject {
    public typealias SuccessfulCompletion = (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    public typealias Completion = (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    public static var osLog: OSLog = OSLog(subsystem: "ProtonDriveFileProvider", category: "ItemActionsOutlet")

    public init() { }
    
    public func deleteItem(tower: Tower,
                           identifier: NSFileProviderItemIdentifier,
                           baseVersion version: NSFileProviderItemVersion,
                           options: NSFileProviderDeleteItemOptions = [],
                           request: NSFileProviderRequest? = nil) async throws
    {
        ConsoleLogger.shared?.log("Delete item \(identifier)", osLogType: Self.self)
        guard let nodeID = NodeIdentifier(identifier) else {
            ConsoleLogger.shared?.log("Failed to delete item: node ID is invalid \(identifier)", osLogType: Self.self)
            throw Errors.nodeNotFound
        }
        
        let itemPlaceholder = ItemPlaceholder(id: identifier)
        if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemPlaceholder, changeType: .delete(version: version), fields: [], contentsURL: nil) {
            throw Errors.deletionRejected(updatedItem: resolvedItem)
        } else {
            #if os(iOS)
            try await tower.delete(nodeID: nodeID)
            #else
            guard let node = self.node(tower: tower, of: identifier) else {
                throw Errors.nodeNotFound
            }
            
            ConsoleLogger.shared?.log("Trashing item...", osLogType: Self.self)
            try await tower.trash(nodes: [node])
            #endif
        }
    }
    
    @discardableResult
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        ConsoleLogger.shared?.log("Modify item \(item.itemIdentifier) fields \(changedFields))", osLogType: Self.self)
        if newContents != nil {
            ConsoleLogger.shared?.log("New cleartext content avaliable at path \(newContents?.path ?? "-")", osLogType: Self.self)
        }
        
        guard let node = self.node(tower: tower, of: item.itemIdentifier) else {
            throw Errors.nodeNotFound
        }
        
        switch OptionSetContainer(changedFields) {
        case .parentItemIdentifier where item.parentItemIdentifier == .trashContainer: // trash
            ConsoleLogger.shared?.log("Trashing item...", osLogType: Self.self)
            try await tower.trash(nodes: [node])
            return (NodeItem(node: node), [], false)
        
        case .parentItemIdentifier where node.state == .deleted && item.parentItemIdentifier != .trashContainer: // untrash
            ConsoleLogger.shared?.log("Restoring item...", osLogType: Self.self)
            try await tower.restoreFromTrash(shareID: node.shareID, nodes: [node.identifier.nodeID])
            return (NodeItem(node: node), [], false)
        
        case .parentItemIdentifier: // move
            ConsoleLogger.shared?.log("Moving item...", osLogType: Self.self)
            guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
                throw Errors.nodeNotFound
            }
            guard let newParent = self.parent(tower: tower, of: item) else {
                throw Errors.parentNotFound
            }

            return try await progressWithMove(tower: tower, item: item, nodeID: nodeID, newParent: newParent, baseVersion: version, changedFields: changedFields, contents: newContents)
            
        case .filename: // rename
            ConsoleLogger.shared?.log("Renaming item...", osLogType: Self.self)
            guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
                throw Errors.nodeNotFound
            }
            guard let parent = self.parent(tower: tower, of: item) else {
                throw Errors.parentNotFound
            }

            return try await progressWithRename(tower: tower, item: item, nodeID: nodeID, parent: parent, baseVersion: version, changedFields: changedFields, contents: newContents)

        case .contents: // upload new revision
            ConsoleLogger.shared?.log("Uploading new contents...", osLogType: Self.self)
            guard tower.sessionVault.currentAddress() != nil else {
                throw Errors.noAddressInTower
            }

            return try await progressWithNewRevision(tower: tower, item: item, node: node, baseVersion: version, changedFields: changedFields, newContents: newContents)

        default:
            ConsoleLogger.shared?.log("Irrelevant changes", osLogType: Self.self)
            return (NodeItem(node: node), [], false)
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
        ConsoleLogger.shared?.log("Create item \(itemTemplate.itemIdentifier) from cleartext content at path \(url?.path ?? "unknown")", osLogType: Self.self)
        
        guard let parent = self.parent(tower: tower, of: itemTemplate) else {
            throw Errors.parentNotFound
        }
        
        if itemTemplate.isFolder {
            ConsoleLogger.shared?.log("Item is a folder", osLogType: Self.self)

            if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .create, fields: fields, contentsURL: url) {
                return (updatedItem, [], false)
            } else {
                let createdFolder = try await tower.createFolder(named: itemTemplate.filename, under: parent)
                return (NodeItem(node: createdFolder), [], false)
            }
        } else {
            ConsoleLogger.shared?.log("Item is a file", osLogType: Self.self)
            guard tower.sessionVault.currentAddress() != nil else {
                throw Errors.noAddressInTower
            }

            if let resolvedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: itemTemplate, changeType: .create, fields: fields, contentsURL: url) {
                return (resolvedItem, [], false)
            }
            
            guard let copy = self.prepare(forUpload: itemTemplate, from: url) else {
                throw Errors.emptyUrlForFileUpload
            }
            
            defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
            
            // Fetch the draft if it already exists otherwise create a new one
            let draft: File
            if let existingDraft = tower.draft(for: itemTemplate) {
                draft = existingDraft
            } else {
                draft = try tower.fileImporter.importFile(from: copy, to: parent, with: itemTemplate.itemIdentifier.rawValue)
            }
            let file = try await tower.fileUploader.upload(draft)
            
            return (NodeItem(node: file), [], false)
        }
    }

    // MARK: - Actions on items

    func progressWithMove(tower: Tower,
                          item: NSFileProviderItem,
                          nodeID: NodeIdentifier,
                          newParent: Folder,
                          baseVersion version: NSFileProviderItemVersion,
                          changedFields: NSFileProviderItemFields,
                          contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        var pendingFields = changedFields
        pendingFields.remove(.parentItemIdentifier)

        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .move(version: version), fields: changedFields, contentsURL: contents) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.move(nodeID: nodeID, under: newParent)
            return (NodeItem(node: node), pendingFields, false)
        }
    }

    func progressWithRename(tower: Tower,
                            item: NSFileProviderItem,
                            nodeID: NodeIdentifier,
                            parent: Folder,
                            baseVersion version: NSFileProviderItemVersion,
                            changedFields: NSFileProviderItemFields,
                            contents: URL?) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        var pendingFields = changedFields
        pendingFields.remove(.filename)

        // Check for conflicts
        let actionChangeType: ItemActionChangeType = changedFields.contains(.parentItemIdentifier) ? .move(version: version) : .modifyMetadata(version: version)
        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: actionChangeType, fields: changedFields, contentsURL: contents) {
            return (updatedItem, pendingFields, false)
        } else {
            let node = try await tower.rename(node: nodeID, cleartextName: item.filename)
            return (NodeItem(node: node), pendingFields, false)
        }
    }

    func progressWithNewRevision(tower: Tower,
                                 item: NSFileProviderItem,
                                 node: Node,
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
        
        guard let copy = self.prepare(forUpload: item, from: newContents) else {
            throw Errors.emptyUrlForFileUpload
        }
        guard let file = node as? File else {
            throw Errors.nodeNotFound
        }
        
        if let updatedItem = try await findAndResolveConflictIfNeeded(tower: tower, item: item, changeType: .modifyContents(version: version, contents: newContents), fields: changedFields, contentsURL: newContents) {
            return (updatedItem, pendingFields, false)
        } else {
            defer {
                try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
            }
            let fileWithNewRevision = try tower.revisionImporter.importNewRevision(from: copy, into: file)
            let fileWithUploadedRevision = try await tower.fileUploader.upload(fileWithNewRevision)
            return (NodeItem(node: fileWithUploadedRevision), pendingFields, false)
        }
    }

}

extension ItemActionsOutlet {
    private func prepare(forUpload itemTemplate: NSFileProviderItem, from url: URL?) -> URL? {
        guard let url = url else { return nil }
        // copy file from system temporary location to app temporary location so it will have correct mime and name
        // TODO: inject mime and name directly into Uploader
        let copyParent = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        let copy = copyParent.appendingPathComponent(itemTemplate.filename)
        try? FileManager.default.removeItem(atPath: copyParent.path)
        try? FileManager.default.createDirectory(at: copyParent, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
    
    private func nodeIdentifier(tower: Tower, for itemIdentifier: NSFileProviderItemIdentifier) -> NodeIdentifier? {
        guard itemIdentifier != .workingSet, itemIdentifier != .trashContainer else {
            return nil
        }
        guard itemIdentifier != .rootContainer else {
            return tower.rootFolderIdentifier()
        }
        return NodeIdentifier(itemIdentifier)
    }
    
    private func parent(tower: Tower, of item: NSFileProviderItem) -> Folder? {
        self.node(tower: tower, of: item.parentItemIdentifier) as? Folder
    }
    
    private func node(tower: Tower, of itemIdentifier: NSFileProviderItemIdentifier) -> Node? {
        guard let parentIdentifier = self.nodeIdentifier(tower: tower, for: itemIdentifier) else {
            return nil
        }
        return tower.fileSystemSlot?.getNode(parentIdentifier)
    }
}
