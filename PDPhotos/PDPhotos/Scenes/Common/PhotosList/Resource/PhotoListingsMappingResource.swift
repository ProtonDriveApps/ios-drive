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

protocol PhotoListingsMappingResourceProtocol {
    func mapSections(listings: [[CoreDataPhotoListing]], downloadingIds: PhotoIdsSet) -> [PhotosListSection]
}

final class PhotoListingsMappingResource: PhotoListingsMappingResourceProtocol {
    private let mimeTypeResource: MimeTypeResource

    init(mimeTypeResource: MimeTypeResource) {
        self.mimeTypeResource = mimeTypeResource
    }

    func mapSections(listings: [[CoreDataPhotoListing]], downloadingIds: PhotoIdsSet) -> [PhotosListSection] {
        return listings.compactMap { makeSection(listings: $0, downloadingIds: downloadingIds) }
    }

    private func makeSection(listings: [CoreDataPhotoListing], downloadingIds: PhotoIdsSet) -> PhotosListSection? {
        // We make sure there's no 2 items in a section with same id. This relies on a fact that listings are
        // sorted by capture time & link id -> so we know that duplicates would be ordered next to each other
        // so we don't have to map to Set and back to array etc.
        // The duplicities ideally never happen, when they do, they are cleaned up during app bootstrap,
        // in worst case they're caught and filtered out here.
        var previousId: PhotoId?
        let models = listings
            .compactMap { coreDataListing in
                let listing = makeListing(listing: coreDataListing, downloadingIds: downloadingIds, previousId: previousId)
                if let id = listing?.id {
                    previousId = id
                }
                return listing
            }
        guard !models.isEmpty else {
            return nil
        }
        guard let month = getMonth(from: listings) else {
            return nil
        }
        return PhotosListSection(month: month, photos: models)
    }

    private func getMonth(from listings: [CoreDataPhotoListing]) -> Date? {
        guard let firstPhoto = listings.first(where: { $0.managedObjectContext != nil }) else {
            return nil
        }
        return firstPhoto.captureTime
    }

    private func makeListing(listing: CoreDataPhotoListing, downloadingIds: PhotoIdsSet, previousId: PhotoId?) -> PhotoListing? {
        guard listing.managedObjectContext != nil else { return nil }
        
        let identifier = listing.photoIdentifier
        guard identifier != previousId else {
            return nil
        }
        
        if let photo = listing.photo {
            let isAllChildrenUploaded = photo.children.allSatisfy { $0.state == .active }
            guard isAllChildrenUploaded else { return nil }
        }
        let metadata = makeMetadata(
            from: listing.photo,
            relatedListings: listing.relatedPhotos,
            downloadingIds: downloadingIds
        )
        return PhotoListing(
            id: identifier,
            albumId: listing.albumID,
            captureTime: listing.captureTime,
            metadata: metadata,
            secondaryPhotos: getSecondaryPhotos(from: listing)
        )
    }

    private func makeMetadata(from photo: Photo?, relatedListings: Set<CoreDataPhotoListing>, downloadingIds: PhotoIdsSet) -> PhotoListing.Metadata? {
        guard let photo, photo.managedObjectContext != nil else {
            return nil
        }
        let isVideo = mimeTypeResource.isVideo(mimeType: photo.mimeType)
        var allIDs = Set(relatedListings.map(\.photoIdentifier))
        allIDs.insert(photo.genericIdentifier)

        return PhotoListing.Metadata(
            isShared: photo.isShared,
            hasDirectShare: photo.hasDirectShare,
            isVideo: isVideo,
            isAvailableOffline: photo.isMarkedOfflineAvailable && photo.isDownloaded && photo.children.allSatisfy { $0.isDownloaded },
            isDownloading: photo.isMarkedOfflineAvailable && !downloadingIds.isDisjoint(with: allIDs),
            burstChildrenCount: getBurstCount(from: photo, hasChildren: !relatedListings.isEmpty),
            isFavorite: (photo.tags ?? []).contains(PhotoTag.favorites.rawValue)
        )
    }

    public func getBurstCount(from photo: Photo, hasChildren: Bool) -> Int? {
        guard hasChildren else {
            return nil
        }
        // Intentionally not using `Photo.canBeBurstPhoto`, since that one is not performance optimized.
        // Solution below uses caching of MimeType to speed up the process
        guard mimeTypeResource.isImage(mimeType: photo.mimeType) else {
            return nil
        }

        let areChildrenPhotos = photo.children.allSatisfy { mimeTypeResource.isImage(mimeType: $0.mimeType) }
        return areChildrenPhotos ? photo.children.count : nil
    }

    private func getSecondaryPhotos(from photo: CoreDataPhotoListing) -> [PhotoId] {
        photo.relatedPhotos.map(\.photoIdentifier)
    }
}
