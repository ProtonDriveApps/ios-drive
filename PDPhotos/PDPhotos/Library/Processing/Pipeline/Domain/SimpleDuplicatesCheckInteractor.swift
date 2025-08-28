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
import PDClient
import PDCoreIOS

// TODO: `Albums` related: rename, is not interactor, since it's coupled with core data. Should be refactored to `Repository` etc
protocol SimplePhotoDuplicatesCheckInteractorProtocol {
    func execute(nodes: [CoreDataPhoto], photoRoot: NodeWithNodeHashKey) async throws -> [CoreDataPhoto]
    func execute(nodes: [CoreDataPhoto], album: NodeWithNodeHashKey) async throws -> [CoreDataPhoto]
}

/// Simplify duplicates check by given `CoreDataPhoto`
final class SimplePhotoDuplicatesCheckInteractor: SimplePhotoDuplicatesCheckInteractorProtocol {
    private let batchSize = 150
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(nodes: [CoreDataPhoto], photoRoot: NodeWithNodeHashKey) async throws -> [CoreDataPhoto] {
        let rootProperty = try await getRootProperty(root: photoRoot)
        let hashes = try await getHashes(from: nodes, rootHashKey: rootProperty.decryptedHashKey)
        let uniqueItems = try await filterHashesByRemote(
            hashes: hashes,
            rootProperty: rootProperty,
            isPhotoRoot: true
        )
        return uniqueItems.map(\.photo)
    }

    func execute(nodes: [CoreDataPhoto], album: NodeWithNodeHashKey) async throws -> [CoreDataPhoto] {
        let rootProperty = try await getRootProperty(root: album)
        let hashes = try await getHashes(from: nodes, rootHashKey: rootProperty.decryptedHashKey)
        let uniqueItems = try await filterHashesByRemote(
            hashes: hashes,
            rootProperty: rootProperty,
            isPhotoRoot: false
        )
        return uniqueItems.map(\.photo)
    }
}

// MARK: - Prepare duplicates parameters
extension SimplePhotoDuplicatesCheckInteractor {
    private func getRootProperty(root: NodeWithNodeHashKey) async throws -> NodeWithNodeHashKeyProperty {
        try await dependencies.context.perform {
            let id = AnyVolumeIdentifier(id: root.id, volumeID: root.volumeID)
            return try self.dependencies.rootReader.getDecryptedProperties(from: id, in: self.dependencies.context)
        }
    }

    private func getHashes(
        from nodes: [CoreDataPhoto],
        rootHashKey: String
    ) async throws -> [PhotoAndHashes] {
        let context = dependencies.context
        return try await context.perform {
            var items: [PhotoAndHashes] = []
            for node in nodes {
                let name = try node.decryptName()
                let nameHash = try self.dependencies.encryptionResource.makeHmac(string: name, hashKey: rootHashKey)
                let contentHash = try self.getContentHash(photo: node, rootHashKey: rootHashKey)
                let item = PhotoAndHashes(photo: node, nameHash: nameHash, contentHash: contentHash)
                items.append(item)
            }
            return items
        }
    }

    private func getContentHash(photo: CoreDataPhoto, rootHashKey: String) throws -> String {
        let contentDigest = try photo.photoRevision.getContentDigest()
        switch contentDigest {
        case let .contentDigest(digest):
            return try dependencies.encryptionResource.makeHmac(string: digest, hashKey: rootHashKey)
        case let .contentHash(legacyContentHash):
            // Fallback in case of missing sha1 in xAttr. Doesn't prevent duplicates per se, but repeating the same
            // duplicate check would fail, since the "incorrect" content hash would already be present.
            // Product's decision.
            return legacyContentHash
        }
    }
}

// MARL: - Filter
extension SimplePhotoDuplicatesCheckInteractor {
    private func filterHashesByRemote(
        hashes: [PhotoAndHashes],
        rootProperty: NodeWithNodeHashKeyProperty,
        isPhotoRoot: Bool
    ) async throws -> [PhotoAndHashes] {
        let batches = hashes.splitInGroups(of: batchSize)
        return try await withThrowingTaskGroup(of: [PhotoAndHashes].self) { [weak self] group in
            guard let self else { return [] }
            for batch in batches {
                group.addTask {
                    if isPhotoRoot {
                        let volumeID = rootProperty.identifier.volumeID
                        return try await self.findUniqueInPhotoRoot(volumeID: volumeID, batch: batch)
                    } else {
                        return try await self.findUniqueIn(album: rootProperty, batch: batch)
                    }
                }
            }
            var items: [PhotoAndHashes] = []
            for try await partialResult in group {
                items += partialResult
            }
            return items
        }
    }

    private func filter(localItems: [PhotoAndHashes], remoteItems: [FindDuplicatesResponse.Item]) -> [PhotoAndHashes] {
        return localItems.filter { localItem in
            !remoteItems.contains(where: { remoteItem in
                remoteItem.hash == localItem.nameHash && remoteItem.contentHash == localItem.contentHash
            })
        }
    }

    private func findUniqueInPhotoRoot(volumeID: String, batch: [PhotoAndHashes]) async throws -> [PhotoAndHashes] {
        let nameHashes = batch.map(\.nameHash)
        let parameters = FindDuplicatesParameters(volumeId: volumeID, nameHashes: nameHashes)
        let results = try await self.dependencies.repository.getPhotosDuplicates(with: parameters)
        return self.filter(localItems: batch, remoteItems: results.duplicateHashes)
    }

    private func findUniqueIn(
        album: NodeWithNodeHashKeyProperty,
        batch: [PhotoAndHashes]
    ) async throws -> [PhotoAndHashes] {
        let nameHashes = batch.map(\.nameHash)
        let parameters = FindDuplicatesInAlbumRequest.Parameters(
            volumeID: album.identifier.volumeID,
            albumID: album.identifier.id,
            nameHashes: nameHashes
        )
        let results = try await dependencies.repository.findDuplicatesInAlbum(parameters: parameters)
        return self.filter(localItems: batch, remoteItems: results.duplicateHashes)
    }
}

extension SimplePhotoDuplicatesCheckInteractor {
    struct Dependencies {
        let context: NSManagedObjectContext
        let encryptionResource: EncryptionResource
        let repository: PhotosDuplicatesRepository & AlbumDuplicateCheckService
        let rootReader: DecryptedNodeHashKeyRepository
    }

    private struct PhotoAndHashes {
        let photo: CoreDataPhoto
        let nameHash: String
        let contentHash: String
    }
}
