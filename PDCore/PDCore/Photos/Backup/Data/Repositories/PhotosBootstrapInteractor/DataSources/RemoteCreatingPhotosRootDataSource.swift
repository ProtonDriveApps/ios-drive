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
    private let finishResource: PhotoShareCreationFinishResource

    public init(storage: StorageManager, sessionVault: SessionVault, photoShareCreator: PhotoShareCreator, finishResource: PhotoShareCreationFinishResource) {
        self.storage = storage
        self.sessionVault = sessionVault
        self.photoShareCreator = photoShareCreator
        self.finishResource = finishResource
    }

    public func getPhotoShare() async throws -> Share {
        
        let shareName = "PhotosShare"
        let RootName = "PhotosRoot"
        let moc = storage.newBackgroundContext()

        let (volumeID, mainShareCreator, volume) = try await moc.perform {
            let (mainShare, volume) = try self.storage.getMainShareAndVolume(in: moc)
            return (volume.id, mainShare.creator, volume)
        }

        guard let mainShareCreator = mainShareCreator else {
            throw Share.InvalidState(message: "No creator found in main share.")
        }

        let signersKit = try sessionVault.make(forSigner: .address(mainShareCreator))
        let addressID = signersKit.address.addressID
        let addressKeyID = signersKit.addressKey.keyID
        let shareKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: signersKit.addressKey.privateKey)
        let rootKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: shareKeys.key)
        let rootHashKey = try Encryptor.generateNodeHashKey(nodeKey: rootKeys.key, passphrase: rootKeys.passphraseRaw)
        let rootName = try Encryptor.encryptAndSign(RootName, key: shareKeys.key, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)

        let photosShare = NewPhotoShare(
            addressID: addressID,
            addressKeyID: addressKeyID,
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
        finishResource.execute()

        return try await moc.perform {
            let address = signersKit.address
            let addressKey = signersKit.addressKey

            let share: Share = Share.fetchOrCreate(id: response.share.shareID, in: moc)
            share.volumeID = volumeID
            share.creator = address.email
            share.addressID = signersKit.address.addressID
            share.addressKeyID = addressKey.keyID
            share.key = shareKeys.key
            share.passphrase = shareKeys.passphrase
            share.passphraseSignature = shareKeys.signature
            share.type = .photos

            volume.shares.insert(share)

            let identifier = NodeIdentifier(response.share.linkID, response.share.shareID, volumeID)
            let root: Folder = Folder.fetchOrCreate(identifier: identifier, in: moc)
            root.setShareID(response.share.shareID)
            root.signatureEmail = address.email
            root.directShares.insert(share)
            root.name = rootName

            root.nodeKey = rootKeys.key
            root.nodePassphrase = rootKeys.passphrase
            root.nodePassphraseSignature = rootKeys.signature

            root.nodeHashKey = rootHashKey

            root.nodeHash = ""
            root.mimeType = ""
            root.nameSignatureEmail = ""
            root.mimeType = Folder.mimeType
            root.createdDate = Date()
            root.modifiedDate = Date()

            try moc.saveOrRollback()

            return share
        }
    }

}
