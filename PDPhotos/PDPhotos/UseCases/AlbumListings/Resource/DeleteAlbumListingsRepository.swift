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

protocol DeleteAlbumListingsRepository {
    func remove(filter: AlbumTag?) async throws
}

final class CoreDataDeleteAlbumListingsRepository: DeleteAlbumListingsRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func remove(filter: AlbumTag?) async throws {
        try await managedObjectContext.perform {
            // Intentionally not using batch delete, since it doesn't clean up relationships
            // The number of albums is limited by product requirement, so we shouldn't encounter performance issues
            let fetchRequest = try self.makeRequest(filter: filter)
            let listings = try self.managedObjectContext.fetch(fetchRequest)
            listings.forEach { listing in
                self.managedObjectContext.delete(listing)
            }
            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func makeRequest(filter: AlbumTag?) throws -> NSFetchRequest<CoreDataAlbumListing> {
        let fetchRequest = CoreDataAlbumListing.fetchRequest()
        fetchRequest.predicate = try makePredicate(filter: filter)
        fetchRequest.returnsObjectsAsFaults = true // We don't need to load the objects' contents
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
            return try makePredicate(isOwnVolume: false)
        }
    }

    private func makePredicate(isOwnVolume: Bool, isFilteredBySharing: Bool = false) throws -> NSPredicate {
        let photoVolumeId = try storageManager.getPhotosVolumeId(in: managedObjectContext) ?! "Missing volume"
        var predicates = [NSPredicate]()
        if isOwnVolume {
            let predicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataAlbumListing.volumeID), photoVolumeId)
            predicates.append(predicate)
        } else {
            let predicate = NSPredicate(format: "%K != %@", #keyPath(CoreDataAlbumListing.volumeID), photoVolumeId)
            predicates.append(predicate)
        }
        if isFilteredBySharing {
            let predicate = NSPredicate(format: "%K != nil", #keyPath(CoreDataAlbumListing.shareID))
            predicates.append(predicate)
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
