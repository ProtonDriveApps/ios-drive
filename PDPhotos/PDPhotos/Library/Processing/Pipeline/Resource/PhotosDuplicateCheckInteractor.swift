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

protocol PhotosDuplicateCheckRepository {
    func filterAgainstPhotoRoot(photoIdentifiers: Set<AnyVolumeIdentifier>) async throws -> Set<AnyVolumeIdentifier>

    func filterAgainstAlbum(
        albumId: AlbumIdentifier,
        photoIdentifiers: Set<AnyVolumeIdentifier>
    ) async throws -> Set<AnyVolumeIdentifier>
}

final class CoreDataPhotosDuplicateCheckRepository: PhotosDuplicateCheckRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager
    private let checkInteractor: SimplePhotoDuplicatesCheckInteractorProtocol

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager, checkInteractor: SimplePhotoDuplicatesCheckInteractorProtocol) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
        self.checkInteractor = checkInteractor
    }

    func filterAgainstPhotoRoot(photoIdentifiers: Set<AnyVolumeIdentifier>) async throws -> Set<AnyVolumeIdentifier> {
        let photoStreamFolder = try await managedObjectContext.perform {
            let root = try self.storageManager.getPhotoStreamRootFolder(in: self.managedObjectContext) ?! "Missing photo root"
            return root.identifier
        }
        return try await filter(photoIdentifiers: photoIdentifiers, destination: .photoRoot(photoStreamFolder.any()))
    }

    func filterAgainstAlbum(
        albumId: AlbumIdentifier,
        photoIdentifiers: Set<AnyVolumeIdentifier>
    ) async throws -> Set<AnyVolumeIdentifier> {
        return try await filter(photoIdentifiers: photoIdentifiers, destination: .album(albumId))
    }

    private func filter(
        photoIdentifiers: Set<AnyVolumeIdentifier>,
        destination: Destination
    ) async throws -> Set<AnyVolumeIdentifier> {
        let nodesAndDestination = try await managedObjectContext.perform {
            let photos = try Photo.fetchOrThrow(identifiers: photoIdentifiers, in: self.managedObjectContext)
            let destinationNode = try Node.fetchOrThrow(
                identifier: destination.identifier,
                allowSubclasses: true,
                in: self.managedObjectContext
            )
            let destination = try destinationNode as? NodeWithNodeHashKey ?! "Missing destination"
            return (photos, destination)
        }

        // Only non-duplicated photos will be returned here
        // Intentionally not running this on managedObjectContext queue
        let filteredPhotos: [CoreDataPhoto]
        switch destination {
        case .photoRoot:
            filteredPhotos = try await checkInteractor.execute(nodes: nodesAndDestination.0, photoRoot: nodesAndDestination.1)
        case .album:
            filteredPhotos = try await checkInteractor.execute(nodes: nodesAndDestination.0, album: nodesAndDestination.1)
        }

        // Only non-duplicated photos will be returned here
        let filteredIds = await managedObjectContext.perform {
            filteredPhotos.map { $0.identifier.any() }
        }
        return Set(filteredIds)
    }
}

extension CoreDataPhotosDuplicateCheckRepository {
    enum Destination {
        case photoRoot(AnyVolumeIdentifier)
        case album(AnyVolumeIdentifier)

        var identifier: AnyVolumeIdentifier {
            switch self {
            case .photoRoot(let id):
                return id
            case .album(let id):
                return id
            }
        }
    }
}
