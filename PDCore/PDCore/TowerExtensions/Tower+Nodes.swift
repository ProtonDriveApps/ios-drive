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

extension Tower {
    public func rootFolderIdentifier() -> NodeIdentifier? {
        var rootIdentifier: NodeIdentifier?
        let moc = self.storage.backgroundContext
        moc.performAndWait {
            
            let creatorAddresses = self.sessionVault.addressIDs
            if let mainShare = self.storage.mainShareOfVolume(by: creatorAddresses, moc: moc),
               let root = mainShare.root as? Folder
            {
                rootIdentifier = root.identifier
            }
        }
        return rootIdentifier
    }
    
    public func createFolder(named name: String, under parent: Folder, handler: @escaping (Result<Folder, Error>) -> Void) {
        let scratchpadMoc = storage.privateChildContext(of: storage.backgroundContext)
        scratchpadMoc.performAndWait {
            do {
                let parent = parent.in(moc: scratchpadMoc)
                let signersKit = try SignersKit(sessionVault: sessionVault)
                let folder: Folder = self.storage.new(with: name, by: "name", in: scratchpadMoc)
                self.cloudSlot?.createFolder(folder, parent: parent, signersKit: signersKit) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case let .success(folder): handler(.success(folder))
                        case let .failure(error): handler(.failure(error))
                        }
                    }
                }
            } catch let error {
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            }
        }
    }
    
    public func rename(node: NodeIdentifier, cleartextName newName: String, handler: @escaping (Result<Node, Error>) -> Void) {
        let scratchpadMoc = storage.privateChildContext(of: storage.backgroundContext)
        scratchpadMoc.performAndWait {
            do {
                guard let node = storage.fetchNode(id: node, moc: scratchpadMoc) else {
                    return handler(.failure(NSError(domain: "Failed to find Node", code: 0, userInfo: nil)))
                }
                let newMime = node is Folder ? Folder.mimeType : URL(fileURLWithPath: newName).mimeType()
                let signersKit = try SignersKit(sessionVault: sessionVault)
                
                self.cloudSlot?.rename(node: node, cleartextName: newName, mimeType: newMime, signersKit: signersKit) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case let .success(node): handler(.success(node))
                        case let .failure(error): handler(.failure(error))
                        }
                    }
                }
            } catch let error {
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            }
        }
    }

    public func setFavourite(_ favorite: Bool, nodes: [Node], handler: @escaping (Result<[Node], Error>) -> Void) {
        // local operation - no need for scratchpad moc as it can't fail
        self.storage.backgroundContext.performAndWait {
            let nodes = nodes.map { $0.in(moc: self.storage.backgroundContext) }
            nodes.forEach { $0.isFavorite = favorite }
            
            do {
                try self.storage.backgroundContext.save()
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
            nodes.forEach { $0.isMarkedOfflineAvailable = mark }
            
            do {
                try self.storage.backgroundContext.save()
                handler(.success(nodes))
            } catch let error {
                handler(.failure(error))
            }
        }
    }
    
    public func move(nodeID nodeIdentifier: NodeIdentifier, under newParent: Folder, with newName: String? = nil, handler: @escaping (Result<Node, Error>) -> Void) {
        let scratchpadMoc = storage.privateChildContext(of: storage.backgroundContext)
        scratchpadMoc.performAndWait {
            do {
                guard let node = self.storage.fetchNode(id: nodeIdentifier, moc: scratchpadMoc) else {
                    return  handler(.failure(CloudSlot.Errors.noNodeFound))
                }
                guard newParent.identifier != node.parentLink?.identifier else {
                    return handler(.success(node))
                }
                let signersKit = try SignersKit(sessionVault: sessionVault)
                self.cloudSlot?.move(node: node, under: newParent, with: newName, signersKit: signersKit, handler: handler)
            } catch let error {
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            }
        }
    }

}
