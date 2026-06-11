// Copyright (c) 2025 Proton AG
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

import CoreData
import Foundation
import PDClient
import PDCore

protocol CreatePhotoVolumeInteractorProtocol {
    func execute(signersKit: SignersKit) async throws -> VolumeID
}

struct CreatePhotoVolumeInteractor: CreatePhotoVolumeInteractorProtocol {
    private let client: PhotoShareMigrateAPIService & TagsMigrationAPIClient
    private let clientUIDProvider: UploadClientUIDProvider
    private let context: NSManagedObjectContext
    private let encryptor: EncryptionResource
    private let localSettings: LocalSettings
    private let shareCreationResource: PhotoShareCreationFinishResource

    init(
        client: PhotoShareMigrateAPIService & TagsMigrationAPIClient,
        clientUIDProvider: UploadClientUIDProvider,
        context: NSManagedObjectContext,
        encryptor: EncryptionResource,
        localSettings: LocalSettings,
        shareCreationResource: PhotoShareCreationFinishResource
    ) {
        self.client = client
        self.clientUIDProvider = clientUIDProvider
        self.context = context
        self.encryptor = encryptor
        self.localSettings = localSettings
        self.shareCreationResource = shareCreationResource
    }

    func execute(signersKit: SignersKit) async throws -> VolumeID {
        let shareKeys = try shareKeys(from: signersKit)
        let share = makeShare(from: signersKit, shareKeys: shareKeys)
        let link = try makeLink(from: signersKit, shareKeys: shareKeys)

        let newVolume = try await client.createPhotoVolume(parameters: .init(share: share, link: link))
        let volumeId = try await createVolume(
            newVolume: newVolume,
            signersKit: signersKit,
            shareKeys: shareKeys,
            link: link
        )
        shareCreationResource.execute() // Telemetry
        try await markStateFinished(volumeID: newVolume.volumeID, rootID: newVolume.share.linkID)
        return volumeId
    }

    private func shareKeys(from signersKit: SignersKit) throws -> KeyCredentials {
        try encryptor.generateNodeKeys(
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey,
            parentKey: signersKit.addressKey.privateKey
        )
    }

    private func makeShare(from signersKit: SignersKit, shareKeys: KeyCredentials) -> CreatePhotoVolumeRequest.Share {
        return .init(
            addressID: signersKit.address.addressID,
            addressKeyID: signersKit.addressKey.keyID,
            key: shareKeys.key,
            passphrase: shareKeys.passphrase,
            passphraseSignature: shareKeys.signature
        )
    }

    private func makeLink(from signersKit: SignersKit, shareKeys: KeyCredentials) throws -> CreatePhotoVolumeRequest.Link {
        let folderName = "PhotosRoot"
        let rootName = try encryptor.encryptAndSign(
            folderName,
            key: shareKeys.key,
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey
        )
        let rootKeys = try encryptor.generateNodeKeys(
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey,
            parentKey: shareKeys.key
        )
        let rootHashKey = try encryptor.generateNodeHashKey(
            nodeKey: rootKeys.key,
            passphrase: rootKeys.passphraseRaw
        )

        return .init(
            name: rootName,
            nodeKey: rootKeys.key,
            nodePassphrase: rootKeys.passphrase,
            nodePassphraseSignature: rootKeys.signature,
            nodeHashKey: rootHashKey
        )
    }

    private func createVolume(
        newVolume: PDClient.Volume,
        signersKit: SignersKit,
        shareKeys: KeyCredentials,
        link: CreatePhotoVolumeRequest.Link
    ) async throws -> VolumeID {
        let address = signersKit.address
        let addressKey = signersKit.addressKey
        return try await context.perform {
            let volume = Volume.fetchOrCreate(id: newVolume.volumeID, in: context)
            volume.type = .photo

            let share = Share.fetchOrCreate(id: newVolume.share.shareID, in: context)
            share.volumeID = newVolume.volumeID
            share.creator = address.email
            share.addressID = address.addressID
            share.addressKeyID = addressKey.keyID
            share.key = shareKeys.key
            share.passphrase = shareKeys.passphrase
            share.passphraseSignature = shareKeys.signature
            share.type = .photos
            volume.shares.insert(share)

            let identifier = NodeIdentifier(newVolume.share.linkID, newVolume.share.shareID, newVolume.volumeID)
            let root: Folder = Folder.fetchOrCreate(identifier: identifier, in: context)
            root.setShareID(newVolume.share.shareID)
            root.signatureEmail = address.email
            root.nameSignatureEmail = address.email
            root.directShares.insert(share)
            root.name = link.name
            root.nodeKey = link.nodeKey
            root.nodePassphrase = link.nodePassphrase
            root.nodePassphraseSignature = link.nodePassphraseSignature
            root.nodeHashKey = link.nodeHashKey
            root.nodeHash = ""
            root.mimeType = Folder.mimeType
            if let createTime = newVolume.createTime {
                root.createdDate = Date(timeIntervalSince1970: createTime)
            }
            if let modifyTime = newVolume.modifyTime {
                root.modifiedDate = Date(timeIntervalSince1970: modifyTime)
            }
            try context.saveOrRollback()
            return volume.id
        }
    }

    private func markStateFinished(volumeID: String, rootID: String) async throws {
        let stateUpdater = DefaultPhotoTagsMigrationStateUpdater(
            tagsMigrationClient: client,
            localSettings: localSettings,
            volumeID: volumeID,
            clientUID: clientUIDProvider.getUploadClientUID()
        )
        try await stateUpdater.markFinished(id: rootID)
    }
}
