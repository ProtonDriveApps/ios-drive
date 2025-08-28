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

protocol LocalFavoritingRepositoryProtocol {
    func getStates(ids: PhotoIdsSet) async throws -> [PhotoFavoriteState]
    func toggle(isFavorite: Bool, ids: PhotoIdsSet) async throws
}

final class LocalFavoritingRepository: LocalFavoritingRepositoryProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager
    private let tagRepository: PhotoTagUpdateRepository

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager, tagRepository: PhotoTagUpdateRepository) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
        self.tagRepository = tagRepository
    }

    func getStates(ids: PhotoIdsSet) async throws -> [PhotoFavoriteState] {
        return try await managedObjectContext.perform {
            let photoVolumeRootId = try self.storageManager.getPhotoStreamRootFolderId(in: self.managedObjectContext) ?! "Missing photo volume"
            let photos = CoreDataPhoto.fetch(identifiers: ids, in: self.managedObjectContext)
            return photos.map { photo in
                let isFavorite = (photo.tags ?? []).contains(PhotoTag.favorites.rawValue)
                return PhotoFavoriteState(
                    id: photo.identifier.any(),
                    isFavorite: isFavorite,
                    isInPhotoStream: photo.parentNode?.id == photoVolumeRootId.id
                )
            }
        }
    }

    func toggle(isFavorite: Bool, ids: PhotoIdsSet) async throws {
        return try await managedObjectContext.perform {
            let photos = CoreDataPhoto.fetch(identifiers: ids, in: self.managedObjectContext)
            photos.forEach { photo in
                if isFavorite {
                    self.tagRepository.appendTag(tag: .favorites, photo: photo)
                } else {
                    self.tagRepository.removeTag(tag: .favorites, photo: photo)
                }
            }
            try self.managedObjectContext.saveOrRollback()
        }
    }
}
