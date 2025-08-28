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
import PDClient

final class CoreDataAlbumFactory {
    private let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func updateOrCreateAlbum(link: Link) -> CoreDataAlbum {
        let albumIdentifier = AlbumIdentifier(id: link.linkID, volumeID: link.volumeID)
        let album = CoreDataAlbum.fetchOrCreate(identifier: albumIdentifier, in: managedObjectContext)
        album.fulfillAlbum(with: link)

        let albumListing = CoreDataAlbumListing.fetchOrCreate(identifier: albumIdentifier, in: managedObjectContext)
        album.albumListing = albumListing
        let photosFromListing = albumListing.photos.compactMap(\.photo)
        album.photos = Set(photosFromListing)
        albumListing.fulfillAlbumListing(with: link)

        if let coverPhotoId = link.albumProperties?.coverLinkID {
            album.coverPhoto = CoreDataPhoto.fetch(id: coverPhotoId, volumeID: link.volumeID, in: managedObjectContext)
        } else {
            album.coverPhoto = nil
        }
        return album
    }
}
