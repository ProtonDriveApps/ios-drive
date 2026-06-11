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
import Photos

public class CoreDataPhotoImporter: PhotoImporter {
    private let moc: NSManagedObjectContext
    private let signersKitFactory: SignersKitFactoryProtocol
    private let uploadClientUIDProvider: UploadClientUIDProvider
    private let skippable: PhotosSkippableCache

    public init(
        moc: NSManagedObjectContext,
        signersKitFactory: SignersKitFactoryProtocol,
        uploadClientUIDProvider: UploadClientUIDProvider,
        skippable: PhotosSkippableCache
    ) {
        self.moc = moc
        self.signersKitFactory = signersKitFactory
        self.uploadClientUIDProvider = uploadClientUIDProvider
        self.skippable = skippable
    }

    public func `import`(_ asset: PhotoAsset, folder: Folder, encryptingFolder: EncryptingFolder) throws -> Photo {
        if let data = hasBeenImported(asset: asset) {
            Log.debug("Asset \(asset.localIdentifier) has been imported", domain: .photosProcessing)
            return data
        }
        
        let addressID = try folder.getContextShareAddressID()
        let signersKit = try signersKitFactory.make(forAddressID: addressID)
        let root = folder
        let parent = encryptingFolder

        let uuid = UUID()
        let clearValidatedName = try asset.filename.validateNodeName(validator: NameValidations.iosName)

        let encryptedName = try Encryptor.encryptAndSign(clearValidatedName, key: parent.nodeKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
        let hash = try Encryptor.hmac(filename: clearValidatedName, parentHashKey: parent.hashKey)

        let nodeKeyPack = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: parent.nodeKey)
        let contentPack = try Encryptor.generateContentKeys(nodeKey: nodeKeyPack.key, nodePassphrase: nodeKeyPack.passphraseRaw)

        // Create new Photo
        let coreDataPhoto: Photo = NSManagedObject.newWithValue(uuid.uuidString, by: "id", in: moc)
        coreDataPhoto.volumeID = folder.volumeID
        coreDataPhoto.name = encryptedName
        coreDataPhoto.nodeHash = hash
        coreDataPhoto.mimeType = asset.mimeType.value
        coreDataPhoto.size = asset.dataSize
        coreDataPhoto.nodeKey = nodeKeyPack.key
        coreDataPhoto.nodePassphrase = nodeKeyPack.passphrase
        coreDataPhoto.nodePassphraseSignature = nodeKeyPack.signature
        coreDataPhoto.contentKeyPacket = contentPack.contentKeyPacketBase64
        coreDataPhoto.contentKeyPacketSignature = contentPack.contentKeyPacketSignature
        coreDataPhoto.clientUID = uploadClientUIDProvider.getUploadClientUID()
        coreDataPhoto.setShareID(parent.shareID)
        coreDataPhoto.signatureEmail = signersKit.address.email
        coreDataPhoto.nameSignatureEmail = signersKit.address.email
        coreDataPhoto.uploadID = uuid
        coreDataPhoto.createdDate = asset.metadata.camera.captureTime ?? Date()
        coreDataPhoto.modifiedDate = asset.metadata.iOSPhotos.modificationTime ?? Date()
        coreDataPhoto.captureTime = asset.metadata.camera.captureTime ?? Date()
        coreDataPhoto.tags = asset.tags

        // Temporary values
        let metadata = try metadata(from: asset)
        let tempMetadata = TemporalMetadata(metadata: metadata).base64Encoded()
        coreDataPhoto.tempBase64Metadata = tempMetadata
        coreDataPhoto.localIdentifier = asset.localIdentifier

        // Start Photo with the .interrupted state
        coreDataPhoto.state = .interrupted

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
        coreDataPhotoRevision.volumeID = folder.volumeID
        coreDataPhotoRevision.exif = encryptedExif.base64EncodedString()
        coreDataPhotoRevision.uploadState = .created
        coreDataPhotoRevision.uploadSize = asset.dataSize
        coreDataPhotoRevision.uploadResourceTypeValue = asset.resourceType
        coreDataPhotoRevision.signatureAddress = signersKit.address.email

        // Relationships
        coreDataPhotoRevision.file = coreDataPhoto // This adds the current coreDataRevision to File's revisions
        coreDataPhotoRevision.photo = coreDataPhoto
        coreDataPhoto.activeRevisionDraft = coreDataPhotoRevision
        coreDataPhoto.parentFolder = root

        Log.info("Import Photo with uploadID: \(uuid) for asset \(asset.metadata.iOSPhotos.identifier), resource type: \(asset.resourceType)", domain: .photosProcessing)
        return coreDataPhoto
    }

    // Prevent duplicate asset import to avoid photo redundancy
    private func hasBeenImported(asset: PhotoAsset) -> CoreDataPhoto? {
        let request = CoreDataPhoto.photoFetchRequest()
        // For photo that be edited after uploading
        let statusPredicate = NSPredicate(format: "%K != %d", #keyPath(Photo.stateRaw), Photo.State.active.rawValue)
        let idPredicate = NSPredicate(format: "localIdentifier == %@", asset.localIdentifier)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [idPredicate, statusPredicate])

        let result = try? moc.fetch(request)
        return result?.first(where: { photo in
            photo.photoRevision.uploadResourceTypeValue == asset.resourceType &&
            photo.decryptedName.lowercased() == asset.filename.lowercased()
        })
    }

    private func metadata(from asset: PhotoAsset) throws -> PhotoAssetMetadata {
        let (isUpdated, newCloudIdentifier) = cloudIdentifier(from: asset)
        var metadata = asset.metadata
        guard isUpdated else { return metadata }
        let oldIOSPhoto = metadata.iOSPhotos

        let pendingFiles = try skippable.pendingFiles(identifier: metadata.iOSPhotos) ?! "Failed to get pending number"
        let iOSPhoto = PhotoAssetMetadata.iOSPhotos(
            identifier: newCloudIdentifier,
            modificationTime: asset.metadata.iOSPhotos.modificationTime
        )
        metadata = metadata.copy(with: iOSPhoto)
        skippable.recordFiles(identifier: iOSPhoto, filesToUpload: pendingFiles)
        skippable.markAsSkippable(oldIOSPhoto, skippableFiles: pendingFiles)
        return metadata
    }

    /// Update cloud identifier if needed
    /// - Returns: (isUpdated, cloudIdentifier)
    private func cloudIdentifier(from asset: PhotoAsset) -> (Bool, String) {
        // When a photo is accessed immediately after being taken,
        // its cloud identifier may still be incomplete.
        // Example (incomplete): 4ADE1042-925C-4658-9652-A663D85B23D3:001:
        // Example (complete):   4ADE1042-925C-4658-9652-A663D85B23D3:001:AT+GAjj04PhngzYZMVjhI1c/Cg7W
        let assetCloudIdentifier = asset.metadata.iOSPhotos.identifier
        let components = assetCloudIdentifier.split(separator: ":")
        if components.count == 3 { return (false, assetCloudIdentifier) }
        let mapping = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: [asset.localIdentifier])
        if let identifier = try? mapping[asset.localIdentifier]?.get() {
            let isCompleted = identifier.stringValue.split(separator: ":").count == 3
            return (isCompleted, identifier.stringValue)
        } else {
            return (false, assetCloudIdentifier)
        }
    }
}
