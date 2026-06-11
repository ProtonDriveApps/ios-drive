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
import PDCore
import PDCoreIOS

protocol FavoritingAlbumPhotoParametersFactoryProtocol {
    func makeParameters(for photoId: AnyVolumeIdentifier) async throws -> FavoritingPhotosParameters.Body
}

enum FavoritingAlbumPhotoParametersFactoryError: Error {
    case missingContentHash
}

// Consider extracting the logic below to a generic implementation - currently it's unnecessarily coupled with favoriting
// but rehashing to a different parent is a common operation also for copy, move etc.
final class FavoritingAlbumPhotoParametersFactory: FavoritingAlbumPhotoParametersFactoryProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager
    private let cryptoMaterialReader: NodeCryptoMaterialReaderProtocol
    private let encryptionResource: EncryptionResource

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager, cryptoMaterialReader: NodeCryptoMaterialReaderProtocol, encryptionResource: EncryptionResource) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
        self.cryptoMaterialReader = cryptoMaterialReader
        self.encryptionResource = encryptionResource
    }

    func makeParameters(for photoId: AnyVolumeIdentifier) async throws -> FavoritingPhotosParameters.Body {
        let rootFolderId = try self.storageManager.getPhotoStreamRootFolderId(in: self.managedObjectContext) ?! "Missing root"
        let parentMaterial = try await self.cryptoMaterialReader.readNodeWithHashKey(identifier: rootFolderId)

        let (photo, secondaryPhotos) = try await managedObjectContext.perform { [managedObjectContext] in
            let photo: CoreDataPhoto = try CoreDataPhoto.fetchOrThrow(identifier: photoId, in: managedObjectContext)
            return (photo, photo.children)
        }

        let primaryMaterial = try await self.makeOutput(photo: photo, parentMaterial: parentMaterial)
        let secondaryMaterials = try await secondaryPhotos.asyncMap { photo in
            try await self.makeOutput(photo: photo, parentMaterial: parentMaterial)
        }

        let photoData = FavoritingPhotosParameters.PhotoData(
            hash: primaryMaterial.hash,
            name: primaryMaterial.name,
            nameSignatureEmail: primaryMaterial.nameSignatureEmail,
            nodePassphrase: primaryMaterial.nodePassphrase,
            contentHash: primaryMaterial.contentHash,
            nodePassphraseSignature: primaryMaterial.nodePassphraseSignature,
            signatureEmail: primaryMaterial.signatureEmail,
            relatedPhotos: secondaryMaterials.map(makeRelatedPhoto)
        )
        return FavoritingPhotosParameters.Body(photoData: photoData)
    }

    private func makeRelatedPhoto(material: UpdatedCryptoMaterial) -> FavoritingPhotosParameters.RelatedPhoto {
        FavoritingPhotosParameters.RelatedPhoto(
            linkID: material.id.id,
            hash: material.hash,
            name: material.name,
            nameSignatureEmail: material.nameSignatureEmail,
            nodePassphrase: material.nodePassphrase,
            contentHash: material.contentHash,
            nodePassphraseSignature: material.nodePassphraseSignature,
            signatureEmail: material.signatureEmail
        )
    }

    private func makeOutput(photo: Photo, parentMaterial: NodeParentCryptoMaterial) async throws -> UpdatedCryptoMaterial {
        let nodeMaterial = try await cryptoMaterialReader.readNode(identifier: photo.identifier.any())
        if nodeMaterial.isAnonymous {
            return try makeAnonymousOutput(node: photo, nodeMaterial: nodeMaterial, parentMaterial: parentMaterial)
        } else {
            return try makeOutput(node: photo, nodeMaterial: nodeMaterial, parentMaterial: parentMaterial)
        }
    }

    private func makeOutput(
        node: Node,
        nodeMaterial: NodeCryptoMaterial,
        parentMaterial: NodeParentCryptoMaterial
    ) throws -> UpdatedCryptoMaterial {
        let newNodePassphrase = try node.reencryptNodePassphrase(
            oldNodePassphrase: nodeMaterial.oldNodePassphrase,
            oldParentKey: nodeMaterial.oldParentKey,
            oldParentPassphrase: nodeMaterial.oldParentPassphrase,
            newParentKey: parentMaterial.nodeKey
        )
        let newEncryptedName = try node.renameNode(
            oldEncryptedName: nodeMaterial.oldNodeName,
            oldParentKey: nodeMaterial.oldParentKey,
            oldParentPassphrase: nodeMaterial.oldParentPassphrase,
            newClearName: nodeMaterial.oldDecryptedNodeName,
            newParentKey: parentMaterial.nodeKey,
            signersKit: nodeMaterial.signersKit
        )
        let newNameHash = try encryptionResource.makeHmac(
            string: nodeMaterial.oldDecryptedNodeName,
            hashKey: parentMaterial.hashKey
        )
        return UpdatedCryptoMaterial(
            id: nodeMaterial.id,
            name: newEncryptedName,
            nodePassphrase: newNodePassphrase,
            hash: newNameHash,
            contentHash: try makeContentHash(nodeMaterial: nodeMaterial, parentMaterial: parentMaterial),
            nodePassphraseSignature: nil,
            nameSignatureEmail: nodeMaterial.signersKit.address.email,
            signatureEmail: nil
        )
    }

    private func makeAnonymousOutput(
        node: Node,
        nodeMaterial: NodeCryptoMaterial,
        parentMaterial: NodeParentCryptoMaterial
    ) throws -> UpdatedCryptoMaterial {
        let newEncryptedName = try node.encryptName(
            cleartext: nodeMaterial.oldDecryptedNodeName,
            parentKey: parentMaterial.nodeKey,
            signersKit: nodeMaterial.signersKit
        )
        let newNameHash = try encryptionResource.makeHmac(
            string: nodeMaterial.oldDecryptedNodeName,
            hashKey: parentMaterial.hashKey
        )
        let newKeys = try encryptionResource.updateNodeKeys(
            passphrase: nodeMaterial.oldDecryptedNodePassphrase,
            addressPassphrase: nodeMaterial.signersKit.addressPassphrase,
            addressPrivateKey: nodeMaterial.signersKit.addressKey.privateKey,
            parentKey: parentMaterial.nodeKey
        )
        return UpdatedCryptoMaterial(
            id: nodeMaterial.id,
            name: newEncryptedName,
            nodePassphrase: newKeys.nodePassphrase,
            hash: newNameHash,
            contentHash: try makeContentHash(nodeMaterial: nodeMaterial, parentMaterial: parentMaterial),
            nodePassphraseSignature: newKeys.signature,
            nameSignatureEmail: nodeMaterial.signersKit.address.email,
            signatureEmail: nodeMaterial.signersKit.address.email
        )
    }

    private func makeContentHash(nodeMaterial: NodeCryptoMaterial, parentMaterial: NodeParentCryptoMaterial) throws -> String {
        switch nodeMaterial.contentDigest {
        case let .contentDigest(digest):
            return try encryptionResource.makeHmac(string: digest, hashKey: parentMaterial.hashKey)
        case let .contentHash(previousContentHash):
            // We fall back to using the previous content hash in cases there's no original decrypted one.
            // It doesn't prevent duplicates per se, but works for repeated move/favoriting action.
            return previousContentHash
        case nil:
            // Photos require content hash
            throw FavoritingAlbumPhotoParametersFactoryError.missingContentHash
        }
    }

    struct UpdatedCryptoMaterial {
        let id: AnyVolumeIdentifier
        let name: String
        let nodePassphrase: String
        let hash: String
        let contentHash: String
        let nodePassphraseSignature: String?
        let nameSignatureEmail: String
        let signatureEmail: String?
    }
}
