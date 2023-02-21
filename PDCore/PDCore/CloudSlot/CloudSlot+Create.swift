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
import ProtonCore_Authentication

extension CloudSlot {
    // MARK: - SEND FROM DB TO CLOUD
    internal func createFolder(_ folder: Folder,
                               parent: Folder,
                               signersKit: SignersKit,
                               handler: @escaping (Result<Folder, Error>) -> Void)
    {
        let scratchpadMoc = folder.managedObjectContext!

        scratchpadMoc.performAndWait {
            do {
                assert(folder.name != nil)
                let cleartextName = try folder.name?.validateNodeName(validator: NameValidations.iosName) ?? "Unnamed"
                
                folder.parentLink = parent
                folder.signatureEmail = signersKit.address.email
                
                let credentials = try folder.generateNodeKeys(signersKit: signersKit)
                let name = try folder.encryptName(cleartext: cleartextName, signersKit: signersKit)
                let hash = try folder.hashFilename(cleartext: cleartextName)
                let hashKey = try folder.generateHashKey(nodeKey: credentials)
                
                folder.shareID = parent.shareID
                folder.name = name
                folder.nameSignatureEmail = signersKit.address.email
                folder.nodeKey = credentials.key
                folder.nodePassphrase = credentials.passphrase
                folder.nodePassphraseSignature = credentials.signature
                folder.nodeHash = hash
                folder.nodeHashKey = hashKey
                folder.state = .active
                folder.mimeType = Folder.mimeType
                folder.createdDate = Date()
                folder.modifiedDate = Date()

                let parameters = NewFolderParameters(name: name,
                                    hash: hash,
                                    parentLinkID: folder.parentLink!.id,
                                    folderKey: credentials.key,
                                    folderHashKey: hashKey,
                                    nodePassphrase: credentials.passphrase,
                                    nodePassphraseSignature: credentials.signature,
                                    signatureAddress: folder.signatureEmail)
                self.client.postFolder(folder.shareID, parameters: parameters) { result in
                    scratchpadMoc.performAndWait {
                        switch result {
                        case .failure(let error):
                            ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                            self.resetScratchpadContext(object: folder) {
                                handler(.failure(error))
                            }
                        case .success(let newFolderMeta):
                            do {
                                let obj = self.update(newFolderMeta, folder: folder)
                                try scratchpadMoc.save()
                                self.moc.performAndWait {
                                    do {
                                        try self.moc.save()
                                        let newObj = obj.in(moc: self.moc)
                                        handler(.success(newObj))
                                    } catch {
                                        ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                        // Folder was successfully created in BE, but for some reason failed to be saved locally, clear local state so that it can be managed by the Events System
                                        self.resetScratchpadContext(object: folder) {
                                            handler(.failure(error))
                                        }
                                    }
                                }
                            } catch let error {
                                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                // Folder was successfully created in BE, but for some reason failed to be saved locally, clear local state so that it can be managed by the Events System
                                self.resetScratchpadContext(object: folder) {
                                    handler(.failure(error))
                                }
                            }
                        }
                    }
                }
            } catch let error {
                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                // Folder was not created in BE, clear local state
                resetScratchpadContext(object: folder) {
                    handler(.failure(error))
                }
            }
        }
    }

    private func resetScratchpadContext(object: NSManagedObject, handler: @escaping () -> Void) {
        let context = object.managedObjectContext!
        context.rollback()
        handler()
    }

    internal func rename(node: Node,
                         cleartextName newNameUnnormalized: String,
                         mimeType: String,
                         signersKit: SignersKit,
                         handler:  @escaping (Result<Node, Error>) -> Void)
    {
        let scratchpadMoc = node.managedObjectContext!

        scratchpadMoc.performAndWait {
            do {
                let newName = try newNameUnnormalized.validateNodeName(validator: NameValidations.iosName)
                let (parentPassphrase, parentKey) = try node.getDirectParentPack()

                let encryptedName = try node.renameNode(
                    oldEncryptedName: node.name!,
                    oldParentKey: parentKey,
                    oldParentPassphrase: parentPassphrase,
                    newClearName: newName,
                    newParentKey: parentKey,
                    signersKit: signersKit
                )
                let hash = try node.hashFilename(cleartext: newName)

                let parameters = RenameNodeParameters(
                    name: encryptedName,
                    hash: hash,
                    MIMEType: mimeType,
                    signatureAddress: signersKit.address.email
                )

                self.client.putRenameNode(shareID: node.shareID, nodeID: node.id, parameters: parameters) { result in
                    scratchpadMoc.performAndWait {
                        switch result {
                        case .failure(let error):
                            ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                            self.resetScratchpadContext(object: node) {
                                handler(.failure(error))
                            }
                        case .success:
                            node.name = encryptedName
                            node.nodeHash = hash
                            node.mimeType = mimeType
                            do {
                                try scratchpadMoc.save()
                                self.moc.performAndWait {
                                    do {
                                        try self.moc.save()
                                        let node = node.in(moc: self.moc)
                                        handler(.success(node))
                                    } catch let error {
                                        ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                        self.resetScratchpadContext(object: node) {
                                            handler(.failure(error))
                                        }
                                    }
                                }
                            } catch let error {
                                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                self.resetScratchpadContext(object: node) {
                                    handler(.failure(error))
                                }
                            }
                        }
                    }
                }
            } catch let error {
                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                resetScratchpadContext(object: node) {
                    handler(.failure(error))
                }
            }
        }
    }
    
    internal func move(node: Node, under newParent: Folder, signersKit: SignersKit, handler: @escaping (Result<Node, Error>) -> Void) {
        let scratchpadMoc = node.managedObjectContext!

        scratchpadMoc.performAndWait {
            do {
                let node = node.in(moc: scratchpadMoc)
                let newParent = newParent.in(moc: scratchpadMoc)
                let clearname = try node.decryptName()

                let oldNodePassphrase = node.nodePassphrase
                let (oldParentPassphrase, oldParentKey) = try node.getDirectParentPack()

                node.clearPassphrase = nil

                node.parentLink = newParent
                let (_, newParentKey) = try node.getDirectParentPack()

                let newPassphrase = try node.reencryptNodePassphrase(
                    oldNodePassphrase: oldNodePassphrase,
                    oldParentKey: oldParentKey,
                    oldParentPassphrase: oldParentPassphrase,
                    newParentKey: newParentKey
                )
                node.nodePassphrase = newPassphrase

                let newName = try node.reencryptNodeNameKeyPacket(
                    oldEncryptedName: node.name!,
                    oldParentKey: oldParentKey,
                    oldParentPassphrase: oldParentPassphrase,
                    newParentKey: newParentKey
                )
                let hash = try node.hashFilename(cleartext: clearname)

                node.name = newName
                node.nodeHash = hash
                node.createdDate = Date()
                node.modifiedDate = Date()

                let parameters = MoveNodeParameters(
                    name: newName,
                    hash: hash,
                    parentLinkID: newParent.id,
                    nodePassphrase: newPassphrase,
                    nodePassphraseSignature: node.nodePassphraseSignature,
                    signatureAddress: node.signatureEmail
                )

                self.client.putMoveNode(shareID: node.shareID, nodeID: node.id, parameters: parameters) { result in
                    scratchpadMoc.performAndWait {
                        switch result {
                        case .failure(let error):
                            ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                            self.resetScratchpadContext(object: node) {
                                handler(.failure(error))
                            }

                        case .success:
                            do {
                                try scratchpadMoc.save() // save temporary moc to self.moc
                                self.moc.performAndWait {
                                    do {
                                        try self.moc.save() // save self.moc to persistent store
                                        let node = node.in(moc: self.moc)
                                        handler(.success(node))

                                    } catch {
                                        ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                        self.resetScratchpadContext(object: node) {
                                            handler(.failure(error))
                                        }
                                    }
                                }
                            } catch {
                                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                self.resetScratchpadContext(object: node) {
                                    handler(.failure(error))
                                }
                            }
                        }
                    }
                }

            } catch {
                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                resetScratchpadContext(object: node) {
                    handler(.failure(error))
                }
            }
        }
    }

    internal func createShare(node: Node, handler: @escaping (Result<Share, Error>) -> Void) {
        let scratchpadMoc = node.managedObjectContext!
        scratchpadMoc.performAndWait {
            do {
                let signersKit = try signersKitFactory.make()
                let share: ShareObj = self.storage.new(with: signersKit.address.email, by: #keyPath(ShareObj.creator), in: scratchpadMoc)
                let shareKeys = try share.generateShareKeys(signersKit: signersKit)
                share.addressID = signersKit.address.addressID
                share.creator = signersKit.address.email
                share.key = shareKeys.key
                share.passphrase = shareKeys.passphrase
                share.passphraseSignature = shareKeys.signature

                let allShares: [ShareObj] = self.storage.unique(with: Set([node.shareID]), in: scratchpadMoc)
                guard let mainShare = allShares.first, mainShare.flags.contains(.main) == true else {
                    throw Errors.couldNotFindMainShareForNewShareCreation
                }
                guard let volume = mainShare.volume, let volumeId = volume.id else {
                    throw Errors.couldNotFindVolumeForNewShareCreation
                }
                share.volume = mainShare.volume
                node.directShares.insert(share)

                let linkType = node.isFolder ? LinkType.folder : .file
                let passphraseKeyPacket = try node.keyPacket(node.nodePassphrase, newKey: shareKeys.key)
                let nameKeyPacket = try node.keyPacket(node.name!, newKey: shareKeys.key)

                let parameters = NewShareParameters(type: 0, // unused on BE yet
                                                    addressID: signersKit.address.addressID,
                                                    name: "New share",
                                                    permissionsMask: .full,
                                                    rootLinkID: node.id,
                                                    linkType: linkType,
                                                    shareKey: shareKeys.key,
                                                    sharePassphrase: shareKeys.passphrase,
                                                    sharePassphraseSignature: shareKeys.signature,
                                                    passphraseKeyPacket: passphraseKeyPacket,
                                                    nameKeyPacket: nameKeyPacket)

                self.client.postShare(volumeID: volumeId, parameters: parameters) { result in
                    switch result {
                    case .failure(let error):
                        ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                        self.resetScratchpadContext(object: node) {
                            handler(.failure(error))
                        }
                    case .success(let shareID):
                        scratchpadMoc.performAndWait {
                            share.id = shareID

                            do {
                                try scratchpadMoc.save()
                                self.moc.performAndWait {
                                    do {
                                        try self.moc.save()
                                        let share = share.in(moc: self.moc)
                                        handler(.success(share))

                                    } catch let error {
                                        ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                        self.resetScratchpadContext(object: node) {
                                            handler(.failure(error))
                                        }
                                    }
                                }

                            } catch {
                                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                                self.resetScratchpadContext(object: node) {
                                    handler(.failure(error))
                                }
                            }
                        }
                    }
                }
            } catch {
                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
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
                        ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
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
                ConsoleLogger.shared?.log(DriveError(error, "Cloudslot"))
                handler(.failure(error))
            }
        }
    }
}

extension NewBlockMeta {
    init(block: UploadBlock) throws {
        let base64Hash = block.sha256.base64EncodedString()
        guard let encSignature = block.encSignature,
              let signatureEmail = block.signatureEmail else {
            throw CloudSlot.Errors.failedToEncryptBlocks
        }
        self.init(hash: base64Hash, encryptedSignature: encSignature, signatureEmail: signatureEmail, size: Int(block.size), index: Int(block.index))
    }

    init(block: UploadableBlock) {
        self.init(hash: block.hash, encryptedSignature: block.encryptedSignature, signatureEmail: block.signatureEmail, size: block.size, index: block.index)
    }
}

extension NewThumbnailMeta {
    init?(thumbnail: UploadableThumbnail?) {
        guard let size = thumbnail?.encrypted.count,
              let hash = thumbnail?.sha256.base64EncodedString() else { return nil }
        self.init(size: size, hash: hash)
    }
}
