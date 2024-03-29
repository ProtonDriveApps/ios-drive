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
import PDClient

public final class RemoteCreatingPhotosRootDataSource: PhotosShareDataSource {
    
    private let storage: StorageManager
    private let sessionVault: SessionVault
    private let photoShareCreator: PhotoShareCreator

    public init(storage: StorageManager, sessionVault: SessionVault, photoShareCreator: PhotoShareCreator) {
        self.storage = storage
        self.sessionVault = sessionVault
        self.photoShareCreator = photoShareCreator
    }

    public func getPhotoShare() async throws -> Share {
        
        let shareName = "PhotosShare"
        let RootName = "PhotosRoot"
        let moc = storage.backgroundContext

        guard let volume = storage.volumes(moc: moc).first else {
            throw Volume.InvalidState(message: "No volume found while trying to create photos share.")
        }

        let volumeID = await moc.perform {
            volume.id
        }

        let signersKit = try sessionVault.make(forSigner: .main)
        let addressID = signersKit.address.addressID
        let shareKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: signersKit.addressKey.privateKey)
        let rootKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: shareKeys.key)
        let rootHashKey = try Encryptor.generateNodeHashKey(nodeKey: rootKeys.key, passphrase: rootKeys.passphraseRaw)
        let rootName = try Encryptor.encryptAndSign(RootName, key: shareKeys.key, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)

        let photosShare = NewPhotoShare(
            addressID: addressID,
            volumeID: volumeID,
            shareName: shareName,
            shareKey: shareKeys.key,
            sharePassphrase: shareKeys.passphrase,
            sharePassphraseSignature: shareKeys.signature,
            nodeName: rootName,
            nodeKey: rootKeys.key,
            nodePassphrase: rootKeys.passphrase,
            nodePassphraseSignature: rootKeys.signature,
            nodeHashKey: rootHashKey
        )

        let response = try await photoShareCreator.createPhotosShare(photoShare: photosShare)

        return try await moc.perform {
            let creator = signersKit.address.email

            let share: Share = self.storage.new(with: response.share.shareID, by: #keyPath(Share.id), in: moc)
            share.addressID = signersKit.address.addressID
            share.creator = creator
            share.key = shareKeys.key
            share.passphrase = shareKeys.passphrase
            share.passphraseSignature = shareKeys.signature
            share.type = .photos

            let root: Folder = self.storage.new(with: response.share.linkID, by: #keyPath(Folder.id), in: moc)
            root.shareID = response.share.shareID
            root.nodeKey = rootKeys.key
            root.nodePassphrase = rootKeys.passphrase
            root.nodePassphraseSignature = rootKeys.signature
            root.signatureEmail = creator
            root.name = rootName
            root.nameSignatureEmail = creator
            root.nodeHashKey = rootHashKey
            root.nodeHash = ""
            root.mimeType = Folder.mimeType
            root.createdDate = Date()
            root.modifiedDate = Date()

            share.volume = volume
            share.root = root

            try moc.saveOrRollback()

            return share
        }
    }

}
