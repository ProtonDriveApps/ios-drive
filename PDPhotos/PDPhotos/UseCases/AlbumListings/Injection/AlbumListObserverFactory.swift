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

final class AlbumListObserverFactory {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager
    private let streamConfiguration: PhotoStreamConfiguration

    init(
        managedObjectContext: NSManagedObjectContext,
        storageManager: StorageManager,
        streamConfiguration: PhotoStreamConfiguration
    ) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
        self.streamConfiguration = streamConfiguration
    }

    func makeObserver(filter: AlbumTag?) throws -> FetchedResultsSectionsController<CoreDataAlbumListing> {
        let controller = try makeController(filter: filter)
        return FetchedResultsSectionsController(controller: controller)
    }

    func makeController(filter: AlbumTag?) throws -> NSFetchedResultsController<CoreDataAlbumListing> {
        let controller = NSFetchedResultsController(
            fetchRequest: try makeFetchedResultsController(filter: filter),
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: "CoreDataAlbumListingFetchCache.\(filter?.rawValue ?? -1)"
        )
        return controller
    }

    private func makeFetchedResultsController(filter: AlbumTag?) throws -> NSFetchRequest<CoreDataAlbumListing> {
        let fetchRequest = CoreDataAlbumListing.fetchRequest()
        fetchRequest.predicate = try makePredicate(filter: filter)
        fetchRequest.returnsObjectsAsFaults = true // We don't need to load the objects' contents
        // ascending = oldest -> newest
        // descending = newest -> oldest 
        fetchRequest.sortDescriptors = [.init(key: #keyPath(CoreDataAlbumListing.lastActivityTime), ascending: false)]
        return fetchRequest
    }

    private func makePredicate(filter: AlbumTag?) throws -> NSPredicate? {
        guard let filter else { return nil }
        switch filter {
        case .myAlbums:
            return try makePredicate(isOwnVolume: true)
        case .shared:
            return try makePredicate(isOwnVolume: true, isFilteredBySharing: true)
        case .sharedWithMe:
            return try makePredicate(isOwnVolume: false, isFilteredBySharing: true)
        }
    }

    private func makePredicate(isOwnVolume: Bool, isFilteredBySharing: Bool = false) throws -> NSPredicate {
        let streamVolumeId = streamConfiguration.volumeId
        var predicates = [NSPredicate]()
        if isOwnVolume {
            let predicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataAlbumListing.volumeID), streamVolumeId)
            predicates.append(predicate)
        } else {
            let predicate = NSPredicate(format: "%K != %@", #keyPath(CoreDataAlbumListing.volumeID), streamVolumeId)
            predicates.append(predicate)
        }
        if isFilteredBySharing {
            let predicate = NSPredicate(format: "%K != nil", #keyPath(CoreDataAlbumListing.shareID))
            predicates.append(predicate)
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
