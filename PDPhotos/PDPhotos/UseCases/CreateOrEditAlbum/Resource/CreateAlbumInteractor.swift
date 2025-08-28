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
import struct PDClient.Link

protocol CreateAlbumInteractorProtocol {
    func execute(parameters: CreateAlbumInteractor.Parameters) async throws -> AnyVolumeIdentifier
}

struct CreateAlbumInteractor: CreateAlbumInteractorProtocol {
    private let dependencies: Dependencies
    private let volumeID: String

    init(dependencies: Dependencies, volumeID: String) {
        self.dependencies = dependencies
        self.volumeID = volumeID
    }

    func execute(parameters: Parameters) async throws -> AnyVolumeIdentifier {
        let signersKit = try dependencies.signersKitFactory.make(forSigner: .main)
        let (root, parentNodeKey, parentDecryptedHashKey) = try await dependencies.photoRootProvider
            .getPhotosRootAndKey()
        let (encryptedName, nameHash) = try encryptName(
            name: parameters.clearName,
            signersKit: signersKit,
            parentNodeKey: parentNodeKey,
            parentDecryptedHashKey: parentDecryptedHashKey
        )
        let nodeKeyPacket = try nodeKeyPacket(from: signersKit, parentNodeKey: parentNodeKey)
        let hashKey = try dependencies.encryptor.generateNodeHashKey(
            nodeKey: nodeKeyPacket.key,
            passphrase: nodeKeyPacket.passphraseRaw
        )

        let requestParameters = CreateAlbumRequest.Parameters(
            locked: parameters.locked,
            link: .init(
                name: encryptedName,
                hash: nameHash,
                nodePassphrase: nodeKeyPacket.passphrase,
                nodePassphraseSignature: nodeKeyPacket.signature,
                signatureEmail: signersKit.address.email,
                nodeKey: nodeKeyPacket.key,
                nodeHashKey: hashKey,
                xAttr: nil
            )
        )
        let linkID = try await dependencies.client.createAlbum(volumeID: volumeID, parameter: requestParameters)
        try await saveCoreDataAlbum(parameter: requestParameters, albumID: linkID, photosRoot: root)
        return .init(id: linkID, volumeID: volumeID)
    }

    private func encryptName(
        name: String,
        signersKit: SignersKit,
        parentNodeKey: String,
        parentDecryptedHashKey: String
    ) throws -> (String, String) {
        let clearName = try clearName(from: name)
        let encryptedName = try dependencies.encryptor.encryptAndSign(
            clearName,
            key: parentNodeKey,
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey
        )
        let nameHash = try dependencies.encryptor.makeHmac(
            string: clearName,
            hashKey: parentDecryptedHashKey
        )
        return (encryptedName, nameHash)
    }

    private func clearName(from name: String) throws -> String {
        let clearName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clearName.isEmpty {
            throw Error.emptyClearName
        }
        return clearName
    }

    private func nodeKeyPacket(from signersKit: SignersKit, parentNodeKey: String) throws -> KeyCredentials {
        try dependencies.encryptor.generateNodeKeys(
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey,
            parentKey: parentNodeKey
        )
    }

    private func saveCoreDataAlbum(
        parameter: CreateAlbumRequest.Parameters,
        albumID: Link.LinkID,
        photosRoot: Folder
    ) async throws {
        let context = dependencies.managedObjectContext
        try await context.perform {
            let album = makeAlbum(parameter: parameter, albumID: albumID, photosRoot: photosRoot, context: context)
            makeListing(album: album, context: context)
            try context.save()
        }
    }

    private func makeAlbum(
        parameter: CreateAlbumRequest.Parameters,
        albumID: Link.LinkID,
        photosRoot: Folder,
        context: NSManagedObjectContext
    ) -> CoreDataAlbum {
        let album = CoreDataAlbum(context: context)
        album.locked = parameter.locked
        album.coverLinkID = nil
        album.mimeType = CoreDataAlbum.mimeType
        album.nodeHashKey = parameter.link.nodeHashKey
        album.nodeKey = parameter.link.nodeKey
        album.nodePassphrase = parameter.link.nodePassphrase
        album.shareID = volumeID
        album.nodePassphraseSignature = parameter.link.nodePassphraseSignature
        album.lastActivityTime = Date()
        album.photoCount = 0
        album.id = albumID
        album.volumeID = volumeID
        album.parentFolder = photosRoot
        album.name = parameter.link.name
        album.nameSignatureEmail = parameter.link.signatureEmail
        album.signatureEmail = parameter.link.signatureEmail
        album.createdDate = Date()
        album.modifiedDate = Date()
        album.nodeHash = parameter.link.hash
        return album
    }

    private func makeListing(
        album: CoreDataAlbum,
        context: NSManagedObjectContext
    ) {
        let listing = CoreDataAlbumListing(context: context)
        listing.id = album.id
        listing.volumeID = album.volumeID
        listing.shareID = nil
        listing.locked = album.locked
        listing.coverLinkID = album.coverLinkID
        listing.photoCount = album.photoCount
        listing.lastActivityTime = Date()
        listing.album = album
    }
}

extension CreateAlbumInteractor {
    struct Parameters {
        let clearName: String
        let locked: Bool = false
    }

    struct Dependencies {
        let client: AlbumAPIService
        let encryptor: EncryptionResource
        let signersKitFactory: SignersKitFactoryProtocol
        let managedObjectContext: NSManagedObjectContext
        let photoRootProvider: PhotoRootInfoProviderProtocol
    }

    enum Error: LocalizedError {
        case emptyClearName
    }
}
