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

protocol PhotoListingsLoadRepositoryProtocol {
    func execute(identifiers: [AnyVolumeIdentifier]) async -> [PhotoListing]
}

/// Load PhotoListing from given identifiers
final class PhotoListingsLoadRepository: PhotoListingsLoadRepositoryProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let mimeTypeResource: MimeTypeResource

    init(managedObjectContext: NSManagedObjectContext, mimeTypeResource: MimeTypeResource) {
        self.managedObjectContext = managedObjectContext
        self.mimeTypeResource = mimeTypeResource
    }

    func execute(identifiers: [AnyVolumeIdentifier]) async -> [PhotoListing] {
        return await managedObjectContext.perform {
            var photoListings: [PhotoListing] = []
            for identifier in identifiers {
                let id = PhotoListingIdentifier(id: identifier.id, albumID: nil, volumeID: identifier.volumeID)
                guard let coreDataListing = CoreDataPhotoListing.fetch(
                    identifier: id,
                    in: self.managedObjectContext
                ) else {
                    Log.error("Can't fetch PhotoListing, id: \(identifier)", error: nil, domain: .albums)
                    continue
                }
                let photoListing = PhotoListing(
                    id: coreDataListing.photoIdentifier,
                    captureTime: coreDataListing.captureTime,
                    metadata: self.makeMetadata(from: coreDataListing.photo),
                    secondaryPhotos: coreDataListing.relatedPhotos.map(\.photoIdentifier)
                )
                photoListings.append(photoListing)
            }
            return photoListings
        }
    }

    private func makeMetadata(from photo: Photo?) -> PhotoListing.Metadata? {
        guard let photo, photo.managedObjectContext != nil else {
            return nil
        }
        let isVideo = mimeTypeResource.isVideo(mimeType: photo.mimeType)
        return PhotoListing.Metadata(
            isShared: photo.isShared,
            hasDirectShare: photo.hasDirectShare,
            isVideo: isVideo,
            isAvailableOffline: photo.isMarkedOfflineAvailable && photo.isDownloaded,
            isDownloading: photo.isMarkedOfflineAvailable,
            burstChildrenCount: photo.canBeBurstPhoto ? photo.children.count : nil,
            isFavorite: (photo.tags ?? []).contains(PhotoTag.favorites.rawValue)
        )
    }
}
