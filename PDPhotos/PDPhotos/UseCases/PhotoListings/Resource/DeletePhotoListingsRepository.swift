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

protocol DeletePhotoListingsRepository {
    /// Assumes operating inside managed object context perform block
    func removeStreamListings(tag: PhotoTag?) throws
    /// Assumes operating inside managed object context perform block
    func removeAlbumListings(albumId: String) throws
    /// Removes listing and saves the context
    func remove(listing: PhotoIdsSet, from albumID: String) async throws
}

final class CoreDataDeletePhotoListingsRepository: DeletePhotoListingsRepository {
    private let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func removeStreamListings(tag: PhotoTag?) throws {
        try remove(tag: tag)
    }

    func removeAlbumListings(albumId: String) throws {
        try remove(albumId: albumId)
    }

    func remove(listing: PhotoIdsSet, from albumID: String) async throws {
        if listing.isEmpty { return }
        let context = managedObjectContext
        try await context.perform {
            var deletedCount = 0
            for list in listing {
                let id = PhotoListingIdentifier(id: list.id, albumID: albumID, volumeID: list.volumeID)
                guard let object = CoreDataPhotoListing.fetch(identifier: id, in: context) else {
                    continue
                }
                context.delete(object)
                deletedCount += 1
            }
            if let volumeID = listing.first?.volumeID {
                let albumID = AnyVolumeIdentifier(id: albumID, volumeID: volumeID)
                let album = CoreDataAlbum.fetch(identifier: albumID, in: context)
                let photoCount = album?.photoCount ?? 0
                let count: Int16 = photoCount - Int16(deletedCount)
                album?.photoCount = max(0, count)

                let albumListing = album?.albumListing
                albumListing?.photoCount = max(0, count)
                if let coverLinkID = album?.coverLinkID, listing.map(\.id).contains(coverLinkID) {
                    album?.coverLinkID = nil
                    albumListing?.coverLinkID = nil
                }
            }
            try context.saveOrRollback()
        }
    }

    private func remove(tag: PhotoTag? = nil, albumId: String? = nil) throws {
        // Intentionally not using batch delete, since it doesn't clean up relationships
        let fetchRequest = try self.makeRequest(tag: tag, albumId: albumId)
        let listings = try self.managedObjectContext.fetch(fetchRequest)
        listings.forEach { listing in
            self.managedObjectContext.delete(listing)
        }
    }

    private func makeRequest(tag: PhotoTag?, albumId: String?) throws -> NSFetchRequest<CoreDataPhotoListing> {
        let fetchRequest = CoreDataPhotoListing.fetchRequest()
        fetchRequest.predicate = try makePredicate(tag: tag, albumId: albumId)
        fetchRequest.returnsObjectsAsFaults = true // We don't need to load the objects' contents
        return fetchRequest
    }

    private func makePredicate(tag: PhotoTag?, albumId: String?) throws -> NSPredicate? {
        var predicates = [NSPredicate]()
        if let albumId {
            predicates.append(NSPredicate(format: "%K == %@", #keyPath(CoreDataPhotoListing.albumID), albumId))
        } else {
            predicates.append(NSPredicate(format: "%K == nil", #keyPath(CoreDataPhotoListing.albumID)))
        }
        if let tag {
            let rawTag = CoreDataPhotoListing.tagsSerializer.serialize(tag: tag.rawValue)
            predicates.append(NSPredicate(format: "%K CONTAINS %@", #keyPath(CoreDataPhotoListing.tagsRaw), rawTag))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
