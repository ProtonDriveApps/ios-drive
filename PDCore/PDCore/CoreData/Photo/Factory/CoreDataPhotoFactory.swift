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

final class CoreDataPhotoFactory {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func updatePhoto(photo: CoreDataPhoto, link: Link) {
        removeTrashedPhotoListingIfNecessary(photo: photo, link: link)
        updateAlbums(photo: photo, link: link)
        updatePhotoStreamListingIfNecessary(photo: photo, link: link)
    }

    private func updateAlbums(photo: CoreDataPhoto, link: Link) {
        let albumIds = (link.photoProperties?.albums ?? []).map(\.albumLinkID)
        // Remove from albums where the photo's no longer contained in
        photo.albums = photo.albums.filter { albumIds.contains($0.id) }

        // Remove listings that are no longer valid
        photo.photoListings.forEach { photoListing in
            removeObsoletePhotoListings(photoListing: photoListing, albumIds: albumIds, link: link)
        }

        // Update existing photo listings and update albums relationship
        albumIds.forEach { albumId in
            updatePhotoListing(photo: photo, link: link, albumId: albumId)
        }
    }

    private func removeObsoletePhotoListings(photoListing: CoreDataPhotoListing, albumIds: [String], link: Link) {
        if let albumId = photoListing.albumID { // photo listing with album parent
            if !albumIds.contains(albumId) {
                // photo has been removed from an album
                managedObjectContext.delete(photoListing)
            }
        } else { // photo listing with stream parent
            if !isLinkInPhotoStream(link: link) {
                // photo has been removed from photo stream (for example by moving)
                managedObjectContext.delete(photoListing)
            }
        }
    }

    private func updatePhotoListing(photo: CoreDataPhoto, link: Link, albumId: String) {
        guard link.state == .active else {
            // Listings should only exist for active link
            photo.photoListings.forEach { managedObjectContext.delete($0) }
            return
        }

        let photoListing = updateOrCreatePhotoListing(photo: photo, link: link, albumId: albumId)

        let albumIdentifier = AlbumIdentifier(id: albumId, volumeID: photo.volumeID)
        if let album = CoreDataAlbum.fetch(identifier: albumIdentifier, in: managedObjectContext) {
            photo.addToAlbums(album)
        }

        let albumListing = CoreDataAlbumListing.fetch(identifier: albumIdentifier, in: managedObjectContext)
        photoListing.album = albumListing
    }

    private func removeTrashedPhotoListingIfNecessary(photo: CoreDataPhoto, link: Link) {
        guard link.state == .deleted else { return }
        photo.photoListings.forEach { managedObjectContext.delete($0) }
    }

    private func updatePhotoStreamListingIfNecessary(photo: CoreDataPhoto, link: Link) {
        guard isLinkInPhotoStream(link: link) else {
            return
        }
        guard link.state == .active else {
            // Listings should only exist for active link
            return
        }

        // Link is owned by the user, so photolisting for the photo stream needs to be added too with albumId nil
        _ = updateOrCreatePhotoListing(photo: photo, link: link, albumId: nil)
    }

    private func updateOrCreatePhotoListing(photo: CoreDataPhoto, link: Link, albumId: String?) -> CoreDataPhotoListing {
        let photoListingIdentifier = PhotoListingIdentifier(id: link.linkID, albumID: albumId, volumeID: photo.volumeID)
        let photoListing = CoreDataPhotoListing.fetchOrCreate(identifier: photoListingIdentifier, in: managedObjectContext)
        photoListing.fulfillListing(with: link)
        photo.addToPhotoListings(photoListing)

        // Fill primary photo if relevant
        if let primaryPhotoId = link.fileProperties?.activeRevision?.photo?.mainPhotoLinkID {
            let primaryPhotoListingIdentifier = PhotoListingIdentifier(id: primaryPhotoId, albumID: albumId, volumeID: photo.volumeID)
            if let primaryPhotoListing = CoreDataPhotoListing.fetch(identifier: primaryPhotoListingIdentifier, in: managedObjectContext) {
                photoListing.primaryPhoto = primaryPhotoListing
            }
        }

        // Fill secondary photos if relevant
        link.fileProperties?.activeRevision?.photo?.relatedPhotosLinkIDs?.forEach { secondaryPhotoId in
            let secondaryPhotoListingIdentifier = PhotoListingIdentifier(id: secondaryPhotoId, albumID: albumId, volumeID: photo.volumeID)
            if let secondaryPhotoListing = CoreDataPhotoListing.fetch(identifier: secondaryPhotoListingIdentifier, in: managedObjectContext) {
                photoListing.addToRelatedPhotos(secondaryPhotoListing)
            }
        }

        return photoListing
    }

    private func isLinkInPhotoStream(link: Link) -> Bool {
        let photoRootId = storageManager.getPhotoStreamRootFolderId(in: managedObjectContext)?.id
        return link.parentLinkID == photoRootId // Otherwise the photo is a direct child of an Album
    }
}
