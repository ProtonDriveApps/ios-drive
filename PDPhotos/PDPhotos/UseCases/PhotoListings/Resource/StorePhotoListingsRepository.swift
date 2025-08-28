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

struct StorePhotoListingsData {
    let listings: [RemotePhotoListing]
    let volumeId: String
    let type: ListingType
    let isResetting: Bool // Whether we should clear DB before inserting new listings

    enum ListingType: Equatable {
        case album(albumId: String)
        case stream(tag: PhotoTag?)

        var albumId: String? {
            if case let .album(albumId) = self {
                return albumId
            } else {
                return nil
            }
        }
    }
}

protocol StorePhotoListingsRepository {
    func storeListings(data: StorePhotoListingsData) async throws
}

final class CoreDataStorePhotoListingsRepository: StorePhotoListingsRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let deleteRepository: DeletePhotoListingsRepository

    init(managedObjectContext: NSManagedObjectContext, deleteRepository: DeletePhotoListingsRepository) {
        self.managedObjectContext = managedObjectContext
        self.deleteRepository = deleteRepository
    }

    func storeListings(data: StorePhotoListingsData) async throws {
        try await managedObjectContext.perform {
            if data.isResetting {
                // Intentionally removing old listings in the same block as adding new ones to provide smooth UX
                try self.removeListings(data: data)
            }
            data.listings.forEach { listing in
                self.makeListing(listing: listing, volumeId: data.volumeId, albumId: data.type.albumId)
            }
            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func removeListings(data: StorePhotoListingsData) throws {
        switch data.type {
        case let .album(albumId):
            try deleteRepository.removeAlbumListings(albumId: albumId)
        case let .stream(tag):
            try deleteRepository.removeStreamListings(tag: tag)
        }
    }

    @discardableResult
    private func makeListing(listing: RemotePhotoListing, volumeId: String, albumId: String? = nil) -> CoreDataPhotoListing {
        let identifier = PhotoListingIdentifier(id: listing.linkID, albumID: albumId, volumeID: volumeId)
        let coreDataListing = CoreDataPhotoListing.fetchOrCreate(identifier: identifier, in: managedObjectContext)
        coreDataListing.id = listing.linkID
        coreDataListing.volumeID = volumeId
        coreDataListing.contentHash = listing.contentHash
        coreDataListing.nameHash = listing.hash
        coreDataListing.addedTime = listing.addedTime
        coreDataListing.captureTime = Date(timeIntervalSince1970: Double(listing.captureTime))
        coreDataListing.albumID = albumId
        coreDataListing.tagsRaw = CoreDataPhotoListing.tagsSerializer.serialize(tags: listing.tags ?? [])

        if let photo = PDCore.Photo.fetch(id: listing.linkID, volumeID: volumeId, in: managedObjectContext) {
            coreDataListing.photo = photo
        }
        if let albumId {
            let albumIdentifier = AlbumIdentifier(id: albumId, volumeID: volumeId)
            if let album = CoreDataAlbumListing.fetch(identifier: albumIdentifier, in: managedObjectContext) {
                coreDataListing.album = album
            }
        }
        if let relatedPhotos = listing.relatedPhotos {
            let relatedPhotosListings = relatedPhotos.map { makeListing(listing: $0, volumeId: volumeId, albumId: albumId) }
            coreDataListing.addToRelatedPhotos(Set(relatedPhotosListings))
        }
        return coreDataListing
    }
}
