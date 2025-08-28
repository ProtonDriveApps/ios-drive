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
import PDCore

protocol PhotosPreviewItemInfoReaderProtocol {
    func loadPhotoListingIDs(from ids: PhotoIdsSet) async -> Set<PhotoListingId>
    func isAllFavoritedPhotos(ids: PhotoIdsSet) async -> Bool
    func getAlbumRole(id: AlbumIdentifier) async -> Role?
    func isCopyToStreamAvailable(id: AnyVolumeIdentifier) async -> Bool
}

final class PhotosPreviewItemInfoReader: PhotosPreviewItemInfoReaderProtocol {
    private let context: NSManagedObjectContext
    private let storageManager: StorageManager

    init(context: NSManagedObjectContext, storageManager: StorageManager) {
        self.context = context
        self.storageManager = storageManager
    }

    func loadPhotoListingIDs(from ids: PhotoIdsSet) async -> Set<PhotoListingId> {
        let context = self.context
        return await context.perform {
            let photos = CoreDataPhoto.fetch(identifiers: ids, in: context)
            let listingIDs = photos.map { photo -> PhotoListingId in
                let primary = photo.identifier.any()
                let secondary = photo.children.map { $0.identifier.any() }
                return .init(primary: primary, secondary: secondary)
            }
            return Set(listingIDs)
        }
    }

    func isAllFavoritedPhotos(ids: PhotoIdsSet) async -> Bool {
        let context = self.context
        return await context.perform {
            let photos = CoreDataPhoto.fetch(identifiers: ids, in: context)
            for photo in photos {
                let isFavorite = (photo.tags ?? []).contains(PhotoTag.favorites.rawValue)
                if isFavorite == false {
                    return false
                }
            }
            return true
        }
    }

    func getAlbumRole(id: AlbumIdentifier) async -> Role? {
        let context = self.context
        return await context.perform {
            guard let album = CoreDataAlbum.fetch(identifier: id, in: context) else { return nil }
            return album.getNodeRole()
        }
    }

    func isCopyToStreamAvailable(id: AnyVolumeIdentifier) async -> Bool {
        let context = self.context
        return await context.perform {
            guard let photo = CoreDataPhoto.fetch(identifier: id, in: context) else {
                Log.error("Failed to get metadata from DB, but it should be there.", error: nil, domain: .albums)
                return false
            }
            guard !photo.hasPhotoStreamListing() else {
                return false
            }
            return true
        }
    }
}
