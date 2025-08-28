// Copyright (c) 2024 Proton AG
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

public protocol VolumeCreatingProtocol {
    func createVolume() async throws -> Volume
}

public final class VolumeCreator: VolumeCreatingProtocol {
    let sessionVault: SessionVault
    let storage: StorageManager
    let client: Client

    public init(sessionVault: SessionVault, storage: StorageManager, client: Client) {
        self.sessionVault = sessionVault
        self.storage = storage
        self.client = client
    }

    public func createVolume() async throws -> Volume {
        let folderName = "root"
        let signersKit = try sessionVault.make(forSigner: .main)
        let context = storage.backgroundContext

        let address = signersKit.address
        let addressKey = signersKit.addressKey

        let shareKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: signersKit.addressKey.privateKey)
        let rootName = try Encryptor.encryptAndSign(folderName, key: shareKeys.key, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
        let rootKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: shareKeys.key)
        let rootHashKey = try Encryptor.generateNodeHashKey(nodeKey: rootKeys.key, passphrase: rootKeys.passphraseRaw)

        let parameters = NewVolumeParameters(
            addressID: address.addressID,
            addressKeyID: addressKey.keyID,
            shareKey: shareKeys.key,
            sharePassphrase: shareKeys.passphrase,
            sharePassphraseSignature: shareKeys.signature,
            folderName: rootName,
            folderKey: rootKeys.key,
            folderPassphrase: rootKeys.passphrase,
            folderPassphraseSignature: rootKeys.signature,
            folderHashKey: rootHashKey
        )

        let newVolume = try await client.postVolume(parameters: parameters)

        return try await context.perform {
            let volume = Volume.fetchOrCreate(id: newVolume.ID, in: context)
            volume.type = .main

            let share = Share.fetchOrCreate(id: newVolume.share.ID, in: context)
            share.volumeID = newVolume.ID
            share.creator = address.email
            share.addressID = address.addressID
            share.addressKeyID = addressKey.keyID
            share.key = shareKeys.key
            share.passphrase = shareKeys.passphrase
            share.passphraseSignature = shareKeys.signature
            share.type = .main

            volume.shares.insert(share)

            let identifier = NodeIdentifier(newVolume.share.linkID, newVolume.share.ID, newVolume.ID)
            let root: Folder = Folder.fetchOrCreate(identifier: identifier, in: context)
            root.setShareID(newVolume.share.ID)
            root.signatureEmail = address.email
            root.directShares.insert(share)
            root.name = rootName

            let rootKeys = try root.generateNodeKeys(signersKit: signersKit)
            root.nodeKey = rootKeys.key
            root.nodePassphrase = rootKeys.passphrase
            root.nodePassphraseSignature = rootKeys.signature

            let rootHashKey = try root.generateHashKey(nodeKey: rootKeys)
            root.nodeHashKey = rootHashKey

            root.nodeHash = ""
            root.signatureEmail = ""
            root.nameSignatureEmail = ""
            root.mimeType = Folder.mimeType
            root.createdDate = Date()
            root.modifiedDate = Date()

            try context.saveOrRollback()

            return volume
        }
    }
}
