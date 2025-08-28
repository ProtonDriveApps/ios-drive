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

struct PhotosListObserverFactory {
    func makeListingAndMetadataObserver(
        configuration: PhotosListConfiguration,
        filter: PhotosListFilter?,
        managedObjectContext: NSManagedObjectContext
    ) -> CompoundFetchedResultsController<CoreDataPhotoListing, CoreDataPhoto> {
        let primaryController = makeListingsController(
            volumeId: configuration.volumeId,
            albumId: configuration.albumId,
            shouldGroupByMonth: !configuration.isSingleSection,
            filter: filter,
            managedObjectContext: managedObjectContext
        )
        let secondaryController = makePhotosController(
            volumeId: configuration.volumeId,
            albumId: configuration.albumId,
            filter: filter,
            managedObjectContext: managedObjectContext
        )
        return CompoundFetchedResultsController(primaryController: primaryController, secondaryController: secondaryController)
    }

    func makeSingleSectionListingObserver(
        managedObjectContext: NSManagedObjectContext,
        volumeId: VolumeID
    ) -> FetchedResultsSectionsController<CoreDataPhotoListing> {
        let fetchedController = makeListingsController(volumeId: volumeId, shouldGroupByMonth: false, managedObjectContext: managedObjectContext)
        return FetchedResultsSectionsController(controller: fetchedController)
    }

    private func makeListingsController(
        volumeId: VolumeID,
        albumId: String? = nil,
        shouldGroupByMonth: Bool,
        filter: PhotosListFilter? = nil,
        managedObjectContext: NSManagedObjectContext
    ) -> NSFetchedResultsController<CoreDataPhotoListing> {
        return NSFetchedResultsController(
            fetchRequest: requestPhotoListings(volumeId: volumeId, albumId: albumId, filter: filter),
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: shouldGroupByMonth ? #keyPath(CoreDataPhotoListing.monthIdentifier) : nil,
            cacheName: "CoreDataPhotoListingFetchCache\(volumeId)\(albumId ?? "stream")\(filter?.description ?? "")"
        )
    }

    private func makePhotosController(
        volumeId: VolumeID,
        albumId: String? = nil,
        filter: PhotosListFilter? = nil,
        managedObjectContext: NSManagedObjectContext
    ) -> NSFetchedResultsController<CoreDataPhoto> {
        return NSFetchedResultsController(
            fetchRequest: requestPhotos(volumeId: volumeId, albumId: albumId, filter: filter),
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: "CoreDataPhotoListingFetchCache\(volumeId)\(albumId ?? "stream")\(filter?.description ?? "")"
        )
    }

    private func requestPhotoListings(
        volumeId: VolumeID,
        albumId: String?,
        filter: PhotosListFilter?
    ) -> NSFetchRequest<CoreDataPhotoListing> {
        let fetchRequest = CoreDataPhotoListing.fetchRequest()
        fetchRequest.sortDescriptors = [
            .init(key: #keyPath(CoreDataPhotoListing.captureTime), ascending: false),
            .init(key: #keyPath(CoreDataPhotoListing.id), ascending: false),
        ]
        var predicates = [
            NSPredicate(format: "%K == nil", #keyPath(CoreDataPhotoListing.primaryPhoto)),
            NSPredicate(format: "%K == %@", #keyPath(CoreDataPhotoListing.volumeID), volumeId)
        ]
        if let albumId = albumId {
            predicates.append(NSPredicate(format: "%K == %@", #keyPath(CoreDataPhotoListing.albumID), albumId))
        } else {
            predicates.append(NSPredicate(format: "%K == nil", #keyPath(CoreDataPhotoListing.albumID)))
        }
        if let tag = filter?.tag {
            let rawTag = CoreDataPhotoListing.tagsSerializer.serialize(tag: tag.rawValue)
            predicates.append(NSPredicate(format: "%K CONTAINS %@", #keyPath(CoreDataPhotoListing.tagsRaw), rawTag))
        }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return fetchRequest
    }

    private func requestPhotos(
        volumeId: VolumeID,
        albumId: String?,
        filter: PhotosListFilter?
    ) -> NSFetchRequest<CoreDataPhoto> {
        let fetchRequest = CoreDataPhoto.photoFetchRequest()
        fetchRequest.sortDescriptors = [
            .init(key: #keyPath(CoreDataPhoto.captureTime), ascending: false),
            .init(key: #keyPath(CoreDataPhoto.id), ascending: false),
        ]
        let predicates = [
            NSPredicate(format: "%K == nil", #keyPath(CoreDataPhoto.parent)),
            NSPredicate(format: "%K == %@", #keyPath(CoreDataPhoto.volumeID), volumeId)
        ]
        // Intentionally not adding more predicates (album or tag), further refactoring of DB would be needed.
        // Performance wise it doesn't seem to be needed. Metadata are generally only updated for actively
        // seen listings. Revisit if needed.
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.returnsObjectsAsFaults = true
        return fetchRequest
    }
}
