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

public class CoreDataPhotoImporter: PhotoImporter {

    private let moc: NSManagedObjectContext
    private let rootRepository: PhotosRootFolderRepository
    private let signersKitFactory: SignersKitFactoryProtocol

    public init(moc: NSManagedObjectContext, rootRepository: PhotosRootFolderRepository, signersKitFactory: SignersKitFactoryProtocol) {
        self.moc = moc
        self.rootRepository = rootRepository
        self.signersKitFactory = signersKitFactory
    }

    public func `import`(_ asset: PhotoAsset) throws -> PDCore.Photo {
        try moc.performAndWait {
            let signersKit = try signersKitFactory.make(forSigner: .main)
            let root = try rootRepository.get()
            let parent = try root.encrypting()

            let uuid = UUID()
            let clearValidatedName = try asset.filename.validateNodeName(validator: NameValidations.iosName)

            let encryptedName = try Encryptor.encryptAndSign(clearValidatedName, key: parent.nodeKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
            let hash = try Encryptor.hmac(filename: clearValidatedName, parentHashKey: parent.hashKey)

            let nodeKeyPack = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: parent.nodeKey)
            let contentPack = try Encryptor.generateContentKeys(nodeKey: nodeKeyPack.key, nodePassphrase: nodeKeyPack.passphraseRaw)

            // Create new Photo
            let coreDataPhoto: Photo = NSManagedObject.newWithValue(uuid.uuidString, by: "id", in: moc)
            coreDataPhoto.name = encryptedName
            coreDataPhoto.nodeHash = hash
            coreDataPhoto.mimeType = asset.url.mimeType()
            coreDataPhoto.nodeKey = nodeKeyPack.key
            coreDataPhoto.nodePassphrase = nodeKeyPack.passphrase
            coreDataPhoto.nodePassphraseSignature = nodeKeyPack.signature
            coreDataPhoto.contentKeyPacket = contentPack.contentKeyPacketBase64
            coreDataPhoto.contentKeyPacketSignature = contentPack.contentKeyPacketSignature
            coreDataPhoto.clientUID = uuid.uuidString
            coreDataPhoto.shareID = parent.shareID
            coreDataPhoto.signatureEmail = signersKit.address.email
            coreDataPhoto.nameSignatureEmail = signersKit.address.email
            coreDataPhoto.uploadID = uuid
            coreDataPhoto.createdDate = Date()
            coreDataPhoto.modifiedDate = Date()
            coreDataPhoto.captureTime = asset.metadata.creationDate ?? Date()

            // Temporary values
            let metadata = TemporalMetadata(
                location: nil,
                camera: nil,
                media: .init(width: asset.metadata.width, height: asset.metadata.height, duration: asset.metadata.duration),
                iOSPhotos: .init(iCloudID: asset.metadata.cloudIdentifier, modificationDate: ISO8601DateFormatter().string(asset.metadata.modifiedDate))
            ).base64Encoded()
            coreDataPhoto.tempBase64Metadata = metadata

            // Start Photo with the uploading state
            coreDataPhoto.state = .uploading
            
            let signingKeyRing = try Decryptor.buildPrivateKeyRing(decryptionKeys: [.init(privateKey: signersKit.addressKey.privateKey, passphrase: signersKit.addressPassphrase)])
            defer { signingKeyRing.clearPrivateParams() }

            // Photo Revision values
            let encryptedExif = try Encryptor.encryptAndSignBinaryWithSessionKey(
                clearData: asset.exif,
                sessionKey: contentPack.contentSessionKey,
                signingKeyRing: signingKeyRing
            )

            // Create new Revision
            let coreDataPhotoRevision: PhotoRevision = NSManagedObject.newWithValue(uuid.uuidString, by: "id", in: moc)
            coreDataPhotoRevision.exif = encryptedExif.base64EncodedString()
            coreDataPhotoRevision.uploadState = .created
            coreDataPhotoRevision.uploadableResourceURL = asset.url
            coreDataPhotoRevision.signatureAddress = signersKit.address.email

            // Relationships
            coreDataPhotoRevision.file = coreDataPhoto // This adds the current coreDataRevision to File's revisions
            coreDataPhotoRevision.photo = coreDataPhoto
            coreDataPhoto.activeRevisionDraft = coreDataPhotoRevision
            coreDataPhoto.parentLink = root

            return coreDataPhoto
        }
    }
}
