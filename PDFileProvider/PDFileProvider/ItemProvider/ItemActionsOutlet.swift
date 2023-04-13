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
    
    @discardableResult
    public func deleteItem(tower: Tower,
                           identifier: NSFileProviderItemIdentifier,
                           baseVersion version: NSFileProviderItemVersion? = nil,
                           options: NSFileProviderDeleteItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           completionHandler: @escaping (Error?) -> Void) -> Progress
    {
        ConsoleLogger.shared?.log("Delete item \(identifier)", osLogType: Self.self)
        guard let nodeID = NodeIdentifier(identifier) else {
            ConsoleLogger.shared?.log("Failed to delete item: node ID is invalid \(identifier)", osLogType: Self.self)
            completionHandler(Errors.nodeNotFound)
            return Progress()
        }
        tower.delete(nodes: [nodeID.nodeID], shareID: nodeID.shareID) { result in
            switch result {
            case .success: completionHandler(nil)
            case let .failure(error): completionHandler(error)
            }
        }
        return Progress()
    }
    
    @discardableResult
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion? = nil,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil,
                           completionHandler: @escaping Completion) -> Progress
    {
        ConsoleLogger.shared?.log("Modify item \(item.itemIdentifier) fields \(changedFields))", osLogType: Self.self)
        if newContents != nil {
            ConsoleLogger.shared?.log("New cleartext content avaliable at path \(newContents?.path ?? "-")", osLogType: Self.self)
        }
        
        guard let node = self.node(tower: tower, of: item.itemIdentifier) else {
            completionHandler(nil, [], false, Errors.nodeNotFound)
            return Progress()
        }
        
        let completion: (Result<Node, Error>) -> Void = { result in
            switch result {
            case let .failure(error):
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                completionHandler(nil, [], false, error)
            case let .success(folder):
                ConsoleLogger.shared?.log("Successfully updated item", osLogType: Self.self)
                let item = NodeItem(node: folder)
                completionHandler(item, [], false, nil)
            }
        }
        
        switch OptionSetContainer(changedFields) {
        case .parentItemIdentifier where item.parentItemIdentifier == .trashContainer: // trash
            ConsoleLogger.shared?.log("Trashing item...", osLogType: Self.self)
            tower.trash(nodes: [node]) { completion($0.flatMap { .success(node) }) }
            return Progress()
        
        case .parentItemIdentifier where node.state == .deleted && item.parentItemIdentifier != .trashContainer: // untrash
            ConsoleLogger.shared?.log("Restoring item...", osLogType: Self.self)
            tower.restoreFromTrash(shareID: node.shareID, nodes: [node.identifier.nodeID]) { completion($0.flatMap { .success(node) }) }
            return Progress()
        
        case .parentItemIdentifier: // move
            ConsoleLogger.shared?.log("Moving item...", osLogType: Self.self)
            guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
                completionHandler(nil, [], false, Errors.nodeNotFound)
                return Progress()
            }
            guard let newParent = self.parent(tower: tower, of: item) else {
                completionHandler(nil, [], false, Errors.parentNotFound)
                return Progress()
            }
            tower.move(nodeID: nodeID, under: newParent, handler: completion)
            return Progress()
            
        case .filename: // rename
            ConsoleLogger.shared?.log("Renaming item...", osLogType: Self.self)
            guard let nodeID = NodeIdentifier(item.itemIdentifier) else {
                completionHandler(nil, [], false, Errors.nodeNotFound)
                return Progress()
            }
            if #available(macOS 12.0, *) {
                // Renaming an item just after creation might fail because it has not been uploaded yet
                // and modifying it will return an error. So needs to be created first
                if let node = self.node(tower: tower, of: item.itemIdentifier),
                   let parentFolder = self.parent(tower: tower, of: item),
                   let state = node.state, state == .deleted {
                    let (updatedItem, conflicted) = resolveConflictOnItemIfNeeded(tower: tower, item: item, changeType: .create, request: request)
                    if conflicted {
                        completionHandler(updatedItem, [], false, nil)
                    } else {
                        tower.createFolder(named: item.filename, under: parentFolder) {
                            completion($0.map { $0 as Node })
                        }
                    }
                    return Progress()
                }
            }
            tower.rename(node: nodeID, cleartextName: item.filename, handler: completion)
            return Progress()
            
        case .contents: // upload new revision
            ConsoleLogger.shared?.log("Uploading new contents...", osLogType: Self.self)
            guard tower.sessionVault.currentAddress() != nil else {
                completionHandler(nil, [], false, Errors.noAddressInTower)
                return Progress()
            }
            guard let copy = self.prepare(forUpload: item, from: newContents) else {
                completionHandler(nil, [], false, Errors.emptyUrlForFileUpload)
                return Progress()
            }
            guard let file = node as? File else {
                completionHandler(nil, [], false, Errors.nodeNotFound)
                return Progress()
            }
            guard let newFile = try? tower.revisionImporter.importNewRevision(from: copy, into: file) else {
                completionHandler(nil, [], false, Errors.failedToCreateModel)
                return Progress()
            }

            let operation = tower.fileUploader.upload(newFile) {
                try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
                completion($0.map { $0 as Node })
            }
            
            return operation.progress

        default:
            ConsoleLogger.shared?.log("Irrelevant changes", osLogType: Self.self)
            return Progress()
        }
    }
    
    @discardableResult
    public func createItem(tower: Tower,
                           basedOn itemTemplate: NSFileProviderItem,
                           fields: NSFileProviderItemFields = [],
                           contents url: URL?,
                           options: NSFileProviderCreateItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           completionHandler: @escaping Completion) -> Progress
    {
        ConsoleLogger.shared?.log("Create item \(itemTemplate.itemIdentifier) from cleartext content at path \(url?.path ?? "unknown")", osLogType: Self.self)
        
        guard let parent = self.parent(tower: tower, of: itemTemplate) else {
            completionHandler(nil, [], false, Errors.parentNotFound)
            return Progress()
        }
        
        let completion: (Result<Node, Error>) -> Void = { result in
            switch result {
            case let .failure(error as NSError):
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                completionHandler(nil, [], false, error)
            case let .success(folder):
                ConsoleLogger.shared?.log("Successfully created item", osLogType: Self.self)
                let item = NodeItem(node: folder)
                completionHandler(item, [], false, nil)
            }
        }
        
        if itemTemplate.isFolder {
            ConsoleLogger.shared?.log("Item is a folder", osLogType: Self.self)
            // Check for conflicts
            let (updatedItem, conflicted) = resolveConflictOnItemIfNeeded(tower: tower, item: itemTemplate, changeType: .create, request: request)
            if conflicted {
                completionHandler(updatedItem, [], false, nil)
            } else {
                tower.createFolder(named: itemTemplate.filename, under: parent) {
                    completion($0.map { $0 as Node })
                }
            }
            return Progress()
        } else {
            ConsoleLogger.shared?.log("Item is a file", osLogType: Self.self)
            guard tower.sessionVault.currentAddress() != nil else {
                completionHandler(nil, [], false, Errors.noAddressInTower)
                return Progress()
            }
            guard let copy = self.prepare(forUpload: itemTemplate, from: url) else {
                completionHandler(nil, [], false, Errors.emptyUrlForFileUpload)
                return Progress()
            }

            let completion: OnUploadCompletion = {
                try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
                completion($0.map { $0 as Node })
            }

            guard let file = try? tower.fileImporter.importFile(from: copy, to: parent) else {
                return Progress()
            }

            let op = tower.fileUploader.upload(file, completion: completion)

            return op.progress
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
            return tower.rootFolder()
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
