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

import Foundation
import CoreData
import FileProvider
import PDClient

extension Tower {
    public func rootFolderAvailable() -> Bool {
        rootFolderIdentifier() != nil
    }
    
    public func rootFolderIdentifier() -> NodeIdentifier? {
        var rootIdentifier: NodeIdentifier?
        let moc = self.storage.backgroundContext
        moc.performAndWait {
            guard let root = fetchRootFolder(in: moc) else { return }
            rootIdentifier = root.identifier
        }
        return rootIdentifier
    }
    
    func fetchRootFolder(in moc: NSManagedObjectContext) -> Folder? {
        Self.fetchRootFolder(sessionVault: sessionVault, storage: storage, in: moc)
    }
    
    static func fetchRootFolder(sessionVault: SessionVault, storage: StorageManager, in moc: NSManagedObjectContext) -> Folder? {
        let creatorAddresses = sessionVault.addressIDs
        guard let mainShare = storage.mainShareOfVolume(by: creatorAddresses, moc: moc) else { return nil }
        return moc.performAndWait { mainShare.root as? Folder }
    }
    
    public func folderForNodeIdentifier(_ nodeId: NodeIdentifier) -> Folder? {
        guard let node = fileSystemSlot?.getNode(nodeId) else { return nil }
        guard let folder = node as? Folder else {
            return node.parentLink
        }
        return folder
    }
    
    public func createFolder(named name: String, under parent: Folder, handler: @escaping (Result<Folder, Error>) -> Void) {
        Task {
            do {
                let folder = try await cloudSlot.createFolder(name, parent: parent)
                handler(.success(folder))
            } catch {
                handler(.failure(error))
            }
        }
    }
    
    public func rename(node: NodeIdentifier, cleartextName newName: String, handler: @escaping (Result<Node, Error>) -> Void) {
        Task {
            do {
                guard let node = storage.fetchNode(id: node, moc: storage.backgroundContext) else {
                    return handler(.failure(NSError(domain: "Failed to find Node", code: 0, userInfo: nil)))
                }

                let newMime: String?
                if node is Folder {
                    newMime = Folder.mimeType
                } else if newName.fileExtension().isEmpty {
                    // Preserve the previous MIME type in case:
                    // 1. The user removed it when renaming; or
                    // 2. It's a Proton Document, which doesn't have an extension on other platforms
                    newMime = nil
                } else {
                    newMime = URL(fileURLWithPath: newName).mimeType()
                }

                try await cloudSlot.rename(node, to: newName, mimeType: newMime)
                handler(.success(node))
            } catch {
                handler(.failure(error))
            }
        }
    }
    
    public func setFavourite(_ favorite: Bool, nodes: [Node], handler: @escaping (Result<[Node], Error>) -> Void) {
        // local operation - no need for scratchpad moc as it can't fail
        self.storage.backgroundContext.performAndWait {
            let nodes = nodes.map { $0.in(moc: self.storage.backgroundContext) }
            nodes.forEach { $0.isFavorite = favorite }
            
            do {
                try self.storage.backgroundContext.saveWithParentLinkCheck()
                handler(.success(nodes))
            } catch let error {
                handler(.failure(error))
            }
        }
    }
    
    public func markOfflineAvailable(_ mark: Bool, nodes: [Node], handler: @escaping (Result<[Node], Error>) -> Void) {
        // performing this on background context will make observation by OfflineSaver less error-prone
        // local operation - no need for scratchpad moc as it can't fail
        self.storage.backgroundContext.perform {
            let nodes = nodes.map { $0.in(moc: self.storage.backgroundContext) }
            nodes.forEach {
                $0.isMarkedOfflineAvailable = mark
                Log.info("Will mark node:\($0.identifier) as offline available", domain: .offlineAvailable)
            }

            do {
                try self.storage.backgroundContext.saveWithParentLinkCheck()
                handler(.success(nodes))
            } catch {
                Log.error("Failed marking nodes as offline available \(error.localizedDescription)", domain: .offlineAvailable)
                handler(.failure(error))
            }
        }
    }
    
    public func move(nodeID nodeIdentifier: NodeIdentifier, under newParent: Folder, with newName: String? = nil, handler: @escaping (Result<Node, Error>) -> Void) {
        Task {
            do {
                let moc = self.storage.backgroundContext
                guard let node = self.storage.fetchNode(id: nodeIdentifier, moc: moc) else {
                    return  handler(.failure(CloudSlot.Errors.noNodeFound))
                }
                // Changed by macOS, this should probably be dealt somewhere else in the file proveider code
                // This should be the case where the system asks us to move a folder to the same parent (no movement)
                let currentParentID = moc.performAndWait { node.parentLink?.identifier }
                guard newParent.identifier != currentParentID else {
                    return handler(.success(node))
                }
                
                let name = try await decryptedName(node, moc, newName)
                try await cloudSlot.move(node: node, to: newParent, name: name)
                handler(.success(node))
            } catch {
                handler(.failure(error))
            }
        }
    }
    
    private func decryptedName(_ node: Node, _ moc: NSManagedObjectContext, _ newName: String?) async throws -> String {
        if let newName {
            return newName
        }
        return try await moc.perform {
            let node = node.in(moc: moc)
            return try node.decryptName()
        }
    }
}
