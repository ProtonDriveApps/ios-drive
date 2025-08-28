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

protocol StoreAlbumListingsRepository {
    func store(listings: [RemoteAlbumListing]) async throws
}

final class CoreDataStoreAlbumListingsRepository: StoreAlbumListingsRepository {
    private let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func store(listings: [RemoteAlbumListing]) async throws {
        try await managedObjectContext.perform {
            listings.forEach { listing in
                self.makeListing(from: listing)
            }
            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func makeListing(from listing: RemoteAlbumListing) {
        let identifier = AlbumIdentifier(id: listing.linkID, volumeID: listing.volumeID)
        let coreDataListing = CoreDataAlbumListing.fetchOrCreate(identifier: identifier, in: managedObjectContext)
        coreDataListing.id = listing.linkID
        coreDataListing.lastActivityTime = Date(timeIntervalSince1970: listing.lastActivityTime)
        coreDataListing.locked = listing.locked
        coreDataListing.photoCount = Int16(listing.photoCount)
        coreDataListing.volumeID = listing.volumeID
        coreDataListing.coverLinkID = listing.coverLinkID
        coreDataListing.shareID = listing.shareID
        if let album = CoreDataAlbum.fetch(identifier: identifier, in: managedObjectContext) {
            coreDataListing.album = album
        }
    }
}
