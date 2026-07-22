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
    public func rootFolderAvailable(moc: NSManagedObjectContext) -> Bool {
        rootFolderIdentifier(moc: moc) != nil
    }
    
    public func rootFolderIdentifier(moc: NSManagedObjectContext) -> NodeIdentifier? {
        var rootIdentifier: NodeIdentifier?
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
    
    public func folderForNodeIdentifier(_ nodeId: NodeIdentifier, moc: NSManagedObjectContext) -> Folder? {
        guard let node = fileSystemSlot?.getNode(nodeId, moc: moc) else { return nil }
        guard let folder = node as? Folder else {
            return moc.performAndWait {
                node.parentLink
            }
        }
        return folder
    }
    
    public func createFolder(named name: String, under parent: Folder, moc: NSManagedObjectContext, handler: @escaping (Result<Folder, Error>) -> Void) {
        Task {
            do {
                let folder = try await cloudSlot.createFolder(name, parent: parent, moc: moc)
                handler(.success(folder))
            } catch {
                handler(.failure(error))
            }
        }
    }
    
    @available(*, deprecated, message: "Wrap the functionality in a standalone object, this should not be responsibility of Tower")
    public func rename(node: NodeIdentifier, cleartextName newName: String, mimeType providedMimeType: String? = nil, moc: NSManagedObjectContext, handler: @escaping (Result<Node, Error>) -> Void) {
        Task {
            do {
                guard let node = storage.fetchNode(id: node, moc: moc) else {
                    return handler(.failure(NSError(domain: "Failed to find Node", code: 0, userInfo: nil)))
                }

                let isProtonFile = moc.performAndWait {
                    (node as? File)?.isProtonFile ?? false
                }

                let newMime: String?
                if node is Folder {
                    newMime = Folder.mimeType
                } else if newName.fileExtension.isEmpty || isProtonFile {
                    // Preserve the previous MIME type in case:
                    // 1. The user removed it when renaming; or
                    // 2. It's a Proton Document, which doesn't have an extension on other platforms
                    newMime = nil
                } else if let providedMimeType {
                    newMime = providedMimeType
                } else {
                    newMime = URL(fileURLWithPath: newName).mimeType()
                }

                try await cloudSlot.rename(node, to: newName, mimeType: newMime, moc: moc)
                handler(.success(node))
            } catch {
                handler(.failure(error))
            }
        }
    }
    
    public func setFavourite(_ favorite: Bool, nodes: [Node], moc: NSManagedObjectContext, handler: @escaping (Result<[Node], Error>) -> Void) {
        // local operation - no need for scratchpad moc as it can't fail
        moc.performAndWait {
            let nodes = nodes.map { $0.in(moc: moc) }
            nodes.forEach { $0.isFavorite = favorite }
            
            do {
                try moc.saveOrRollback()
                handler(.success(nodes))
            } catch let error {
                handler(.failure(error))
            }
        }
    }
    
    public func markOfflineAvailable(_ mark: Bool, nodes: [Node], moc: NSManagedObjectContext, handler: @escaping (Result<[Node], Error>) -> Void) {
        moc.perform {
            let nodes = nodes.map { $0.in(moc: moc) }
            nodes.forEach {
                $0.isMarkedOfflineAvailable = mark
                Log.info("Will toggle offline available mark to: \(mark). Node:\($0.identifier)", domain: .offlineAvailable)
            }

            do {
                try moc.saveOrRollback()
                handler(.success(nodes))
            } catch {
                Log.error("Failed marking nodes as offline available", error: error, domain: .offlineAvailable)
                handler(.failure(error))
            }
        }
    }

    public func move(nodeID nodeIdentifier: NodeIdentifier, under newParent: Folder, with newName: String? = nil, moc: NSManagedObjectContext, handler: @escaping (Result<Node, Error>) -> Void) {
        Task {
            do {
                guard let node = self.storage.fetchNode(id: nodeIdentifier, moc: moc) else {
                    return handler(.failure(CloudSlot.Errors.noNodeFound))
                }
                // Changed by macOS, this should probably be dealt somewhere else in the file proveider code
                // This should be the case where the system asks us to move a folder to the same parent (no movement)
                let currentParentID = moc.performAndWait { node.parentNode?.identifier }
                guard newParent.identifier != currentParentID else {
                    return handler(.success(node))
                }

                let name = try await decryptedName(node, moc, newName)
                try await cloudSlot.move(node: node, to: newParent, name: name, moc: moc)
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
