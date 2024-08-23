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
import PDClient
import ProtonCoreAuthentication

extension CloudSlot {
    public func createFolder(_ name: String, parent: Folder) async throws -> Folder {
        let creator = FolderCreator(storage: storage, cloudFolderCreator: client.createFolder, signersKitFactory: signersKitFactory, moc: storage.backgroundContext)

        return try await creator.createFolder(name, parent: parent)
    }

    @available(*, deprecated, message: "use async/await createFolder")
    func createFolder(_ name: String, parent: Folder, handler: @escaping (Result<Folder, Error>) -> Void) {
        Task {
            do {
                let folder = try await createFolder(name, parent: parent)
                handler(.success(folder))
            } catch {
                handler(.failure(error))
            }
        }
    }

    public func rename(_ node: Node, to newName: String, mimeType: String?) async throws {
        let renamer = NodeRenamer(storage: storage, cloudNodeRenamer: client.renameEntry, signersKitFactory: signersKitFactory, moc: storage.backgroundContext)

        return try await renamer.rename(node, to: newName, mimeType: mimeType)
    }

    @available(*, deprecated, message: "use async/await rename")
    func rename(node: Node, cleartextName newNameUnnormalized: String, mimeType: String, handler: @escaping (Result<Node, Error>) -> Void) {
        Task {
            do {
                try await rename(node, to: newNameUnnormalized, mimeType: mimeType)
                handler(.success(node))
            } catch {
                handler(.failure(error))
            }
        }
    }
    
    public func move(node: Node, to newParent: Folder, name: String) async throws {
        let mover = NodeMover(storage: storage, cloudNodeMover: client.moveEntry, signersKitFactory: signersKitFactory, moc: storage.backgroundContext)

        return try await mover.move(node, to: newParent, name: name)
    }

    @available(*, deprecated, message: "use async/await move")
    func move(node: Node, under newParent: Folder, with newName: String, handler: @escaping (Result<Node, Error>) -> Void) {
        Task {
            do {
                try await move(node: node, to: newParent, name: newName)
                handler(.success(node))
            } catch {
                handler(.failure(error))
            }
        }
    }

    public func createShare(for node: Node) async throws -> Share {
        let shareCreator = ShareCreator(storage: storage, sessionVault: sessionVault, cloudShareCreator: client.createShare, signersKitFactory: signersKitFactory, moc: storage.backgroundContext)

        return try await shareCreator.create(for: node)
    }

    internal func createShare(node: Node, handler: @escaping (Result<Share, Error>) -> Void) {
        Task {
            do {
                let share = try await createShare(for: node)
                handler(.success(share))
            } catch {
                handler(.failure(error))
            }
        }
    }

    internal func createVolume(signersKit: SignersKit, handler: @escaping (Result<Share, Error>) -> Void) {
        let volumeName = "MainVolume"
        let shareName = "MainShare"
        let folderName = "root"

        self.moc.performAndWait {
            do {
                let address = signersKit.address
                let share: ShareObj = self.storage.new(with: address.email, by: #keyPath(ShareObj.creator), in: self.moc)
                let shareKeys = try share.generateShareKeys(signersKit: signersKit)
                share.addressID = address.addressID
                share.key = shareKeys.key
                share.passphrase = shareKeys.passphrase
                share.passphraseSignature = shareKeys.signature
                
                let root: FolderObj = self.storage.new(with: address.email, by: #keyPath(FolderObj.signatureEmail), in: self.moc)
                root.directShares.insert(share)
                
                let rootName = try root.encryptName(cleartext: folderName, signersKit: signersKit)
                root.name = rootName
                
                let rootKeys = try root.generateNodeKeys(signersKit: signersKit)
                root.nodeKey = rootKeys.key
                root.nodePassphrase = rootKeys.passphrase
                root.nodePassphraseSignature = rootKeys.signature
                
                let rootHashKey = try root.generateHashKey(nodeKey: rootKeys)
                root.nodeHashKey = rootHashKey
                
                root.nodeHash = ""
                root.mimeType = ""
                root.signatureEmail = ""
                root.nameSignatureEmail = ""
                root.createdDate = Date()
                root.modifiedDate = Date()
                
                let parameters = NewVolumeParameters.init(addressID: address.addressID,
                                                          volumeName: volumeName,
                                                          shareName: shareName,
                                                          folderName: rootName,
                                                          sharePassphrase: shareKeys.passphrase,
                                                          sharePassphraseSignature: shareKeys.signature,
                                                          shareKey: shareKeys.key,
                                                          folderPassphrase: rootKeys.passphrase,
                                                          folderPassphraseSignature: rootKeys.signature,
                                                          folderKey: rootKeys.key,
                                                          folderHashKey: rootHashKey)
                 
                self.client.postVolume(parameters: parameters) {
                    switch $0 {
                    case .failure(let error):
                        Log.error(DriveError(error), domain: .networking)
                        handler(.failure(error))

                    case .success(let newVolume):
                        self.moc.performAndWait {
                            share.id = newVolume.share.ID
                            root.id = newVolume.share.linkID
                            root.shareID = newVolume.share.ID
                            
                            let volume: VolumeObj = self.storage.new(with: newVolume.ID, by: "id", in: self.moc)
                            volume.shares.insert(share)

                            handler(.success(share))
                        }
                    }
                }

            } catch {
                Log.error(DriveError(error), domain: .encryption)
                handler(.failure(error))
            }
        }
    }
    
    internal func createVolumeAsync(signersKit: SignersKit) async throws -> Share {
        return try await withCheckedThrowingContinuation { continuation in
            createVolume(signersKit: signersKit) { result in
                switch result {
                case .success(let share):
                    continuation.resume(returning: share)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

}
