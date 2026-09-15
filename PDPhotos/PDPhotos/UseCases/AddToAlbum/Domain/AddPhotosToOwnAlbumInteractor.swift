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

protocol AddPhotosToOwnAlbumInteractorProtocol {
    func execute(parameters: AddPhotosToOwnAlbumInteractor.Parameters) async throws -> AlbumContentOperationResult
}

enum AddPhotosToOwnAlbumInteractorError: Error {
    case missingMetadata
}

struct AddPhotosToOwnAlbumInteractor: AddPhotosToOwnAlbumInteractorProtocol {
    private struct AddPhotosData {
        let failedIds: [String]
        let childIds: [String]
        let photos: [PhotoCompound]
        let incompleteCount: Int
        let duplicatesCount: Int

        // compound contains primary + all secondary photos
        typealias PhotoCompound = [AddExistingPhotosToAlbumRequest.AlbumData]
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(parameters: Parameters) async throws -> AlbumContentOperationResult {
        // The user may have selected incomplete listing in album. We need to make sure we have metadata for all children.
        try await fetchMetadata(ids: parameters.primaryIds)

        let signersKit = try dependencies.signersKitFactory.make(forSigner: .main)
        let data = try await makeAlbumData(with: parameters, signersKit: signersKit)
        var failedIDs = data.failedIds

        guard !data.photos.isEmpty else {
            return AlbumContentOperationResult(failure: data.failedIds.count, success: 0, duplication: data.duplicatesCount, incomplete: data.incompleteCount)
        }

        // Initially the client can only send maximum 10 entries per request due to potential load on the server.
        let batches = makeBatches(data: data)
        let responses = try await withThrowingTaskGroup(of: AddExistingPhotosToAlbumResponse.self) { group in
            for batch in batches {
                group.addTask {
                    return try await dependencies.client.addExistingPhotosToAlbum(
                        volumeID: parameters.albumID.volumeID,
                        linkID: parameters.albumID.id,
                        body: .init(albumData: batch)
                    )
                }
            }
            var responses: [AddExistingPhotosToAlbumResponse] = []
            for try await result in group {
                responses.append(result)
            }
            return responses
        }
        let photoResponses = responses.flatMap(\.responses)
        var successIDs: [String] = []
        var duplicatedIDs: [String] = []
        for res in photoResponses {
            if data.childIds.contains(res.linkID) { continue }
            if res.response.code == 1000 {
                let newLinkID = res.response.details?.newLinkID ?? res.linkID
                successIDs.append(newLinkID)
            } else if res.response.code == 2500 {
                duplicatedIDs.append(res.linkID)
            } else {
                failedIDs.append(res.linkID)
            }
        }
        try await updateLocalDB(
            albumID: parameters.albumID,
            coverLinkID: successIDs.first,
            newAddedPhotos: successIDs.count
        )

        let result = AlbumContentOperationResult(
            failure: failedIDs.count,
            success: successIDs.count,
            duplication: duplicatedIDs.count + data.duplicatesCount,
            incomplete: data.incompleteCount
        )

        let messages: [String] = [
            "Add \(parameters.primaryIds.count) photos to album: \(parameters.albumID)",
            result.description
        ]
        Log.debug(messages.joined(separator: "\n"), domain: .albums)
        return result
    }

    private func makeBatches(data: AddPhotosData) -> [[AddExistingPhotosToAlbumRequest.AlbumData]] {
        // Batches need to have 10 items max.
        // primary + secondary items need to be together in one batch.
        // For large compounds (for example bursts with > 9 children), BE will need to adjust the threshold.
        var batches = [[AddExistingPhotosToAlbumRequest.AlbumData]]()
        var currentBatch = [AddExistingPhotosToAlbumRequest.AlbumData]()
        data.photos.forEach { compound in
            if (currentBatch.count + compound.count) <= 10 {
                currentBatch += compound
            } else {
                batches.append(currentBatch)
                currentBatch = compound
            }
        }
        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }
        return batches.filter { !$0.isEmpty }
    }

    private func makeAlbumData(
        with parameters: Parameters,
        signersKit: SignersKit
    ) async throws -> AddPhotosData {
        let (nodeKey, decryptedNodeHashKey) = try await dependencies.albumKeyProvider
            .loadAlbumKey(id: parameters.albumID)
        let context = dependencies.context
        return try await context.perform {
            var failedIDs: [String] = []
            var childIDs: [String] = []
            var incompleteCount: Int = 0
            let data = try parameters.primaryIds
                .compactMap { photoID -> AddPhotosData.PhotoCompound? in
                    guard let photo = CoreDataPhoto.fetch(identifier: photoID, in: context) else {
                        Log.error("Failed to fetch selected photo to add to album: \(photoID)", error: nil, domain: .albums)
                        return nil
                    }

                    let listingsIds = photo.photoListings.flatMap { [$0.id] + $0.relatedPhotos.map(\.id) }
                    let listingIdsSet = Set(listingsIds)
                    let metadataIds = [photo.id] + photo.children.map(\.id)
                    guard Set(listingIdsSet).isSubset(of: metadataIds) else {
                        assertionFailure("Should not happen. DB inconsistency.")
                        Log.error("Inconsistent data in DB. listing ids: \(listingIdsSet), metadata ids: \(metadataIds)", error: nil, domain: .albums)
                        throw AddPhotosToOwnAlbumInteractorError.missingMetadata
                    }

                    do {
                        let allPhotos = [photo] + photo.children
                        guard allPhotos.allSatisfy({ $0.state == .active }) else {
                            incompleteCount += 1
                            Log.info("Tried to add photo to album which is not fully uploaded.", domain: .albums)
                            return nil
                        }
                        childIDs.append(contentsOf: photo.children.map(\.id))
                        let compound = try allPhotos.compactMap { photo in
                            try self.makeAlbumData(
                                decryptedHashKey: decryptedNodeHashKey,
                                photo: photo,
                                nodeKey: nodeKey,
                                signersKit: signersKit
                            )
                        }
                        guard !compound.isEmpty else {
                            return nil
                        }
                        return compound
                    } catch {
                        failedIDs.append(photoID.id)
                        Log.error(error: error, domain: .albums)
                        return nil
                    }
                }
            return AddPhotosData(failedIds: failedIDs, childIds: childIDs, photos: data, incompleteCount: incompleteCount, duplicatesCount: 0)
        }
    }

    private func fetchMetadata(ids: [AnyVolumeIdentifier]) async throws {
        // Ids may contain only parent ids, we need to make sure all children are fetched too
        var allIds = Set<AnyVolumeIdentifier>()

        let context = dependencies.context
        await context.perform {
            ids.forEach { id in
                let listings: [CoreDataPhotoListing] = CoreDataPhotoListing.fetchAll(identifier: id, in: context)
                let allListingsIds = listings.flatMap { [$0.photoIdentifier] + $0.relatedPhotos.map(\.photoIdentifier) }
                allIds.formUnion(allListingsIds)
            }
        }

        _ = try await dependencies.metadataResource.fetch(identifiers: Array(allIds), forceToRefresh: false)
    }

    // This is so photos from photo-stream can be added to an album (without re-uploading content)
    // Creates new nodePassphrase based on the album node (and not the photos root share)
    // Re-encrypt name with album node key
    private func makeAlbumData(
        decryptedHashKey: Data,
        photo: CoreDataPhoto,
        nodeKey: String,
        signersKit: SignersKit
    ) throws -> AddExistingPhotosToAlbumRequest.AlbumData? {
        let cryptoInfo = try dependencies.infoReader.readNode(identifier: .init(id: photo.id, volumeID: photo.volumeID))

        let reencryptedName = try dependencies.encryptor.reencryptKeyPacket(
            of: cryptoInfo.oldNodeName,
            oldParentKey: cryptoInfo.oldParentKey,
            oldParentPassphrase: cryptoInfo.oldParentPassphrase,
            newParentKey: nodeKey
        )
        let newNodePassphrase = try dependencies.encryptor.reencryptKeyPacket(
            of: photo.nodePassphrase,
            oldParentKey: cryptoInfo.oldParentKey,
            oldParentPassphrase: cryptoInfo.oldParentPassphrase,
            newParentKey: nodeKey
        )
        let nameHash = try dependencies.encryptor.makeHmac(
            string: cryptoInfo.oldDecryptedNodeName,
            hashKey: decryptedHashKey
        )
        let contentHash = try rehashed(
            contentDigest: cryptoInfo.contentDigest,
            albumDecryptedHashKey: decryptedHashKey
        )
        return AddExistingPhotosToAlbumRequest.AlbumData(
            linkID: photo.id,
            hash: nameHash,
            name: reencryptedName,
            nameSignatureEmail: signersKit.address.email,
            nodePassphrase: newNodePassphrase,
            contentHash: contentHash,
            nodePassphraseSignature: nil,
            signatureEmail: nil
        )
    }

    private func nodeKeyPacket(from signersKit: SignersKit, parentNodeKey: String) throws -> KeyCredentials {
        try dependencies.encryptor.generateNodeKeys(
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey,
            parentKey: parentNodeKey
        )
    }

    private func rehashed(contentDigest: FileContentDigest?, albumDecryptedHashKey: Data) throws -> String {
        guard let contentDigest else { throw AddPhotosError.ContentDigestMissing }

        switch contentDigest {
        case .contentDigest(let digest):
            return try dependencies.encryptor.makeHmac(string: digest, hashKey: albumDecryptedHashKey)
        case .contentHash(let string):
            return string
        }
    }
}

extension AddPhotosToOwnAlbumInteractor {
    private func updateLocalDB(albumID: AnyVolumeIdentifier, coverLinkID: String?, newAddedPhotos: Int) async throws {
        let context = dependencies.context
        try await context.perform {
            guard
                let album = CoreDataAlbum.fetch(identifier: albumID, in: context),
                let listing = album.albumListing
            else { return }

            album.photoCount += Int16(newAddedPhotos)
            listing.photoCount += Int16(newAddedPhotos)
            if let coverLinkID, album.coverLinkID == nil {
                album.coverLinkID = coverLinkID
                listing.coverLinkID = coverLinkID
                let photoID = AnyVolumeIdentifier(id: coverLinkID, volumeID: albumID.volumeID)
                if let photo = CoreDataPhoto.fetch(identifier: photoID, in: context) {
                    album.coverPhoto = photo
                }
            }

            try context.saveOrRollback()
        }
    }
}

extension AddPhotosToOwnAlbumInteractor {
    struct Dependencies {
        let albumKeyProvider: AlbumKeyProviderProtocol
        let client: AlbumPhotosAPIService
        let context: NSManagedObjectContext
        let encryptor: EncryptionResource
        let infoReader: NodeCryptoMaterialReaderProtocol
        let signersKitFactory: SignersKitFactoryProtocol
        let metadataResource: RemoteMetadataFetchRepositoryProtocol
    }

    struct Parameters {
        let albumID: AnyVolumeIdentifier
        let primaryIds: [PhotoId]
    }

    enum AddPhotosError: Error {
        case ContentDigestMissing
    }
}
