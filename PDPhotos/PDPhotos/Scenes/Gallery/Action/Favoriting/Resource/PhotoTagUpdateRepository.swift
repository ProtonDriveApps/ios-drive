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

final class PhotoTagUpdateRepository {
    func appendTag(tag: PhotoTag, photo: CoreDataPhoto) {
        let updatedArray = Array(Set((photo.tags ?? []) + [tag.rawValue]))
        photo.tags = updatedArray
        photo.photoListings.forEach { listing in
            appendTag(tag: tag, listing: listing)
        }
    }

    func removeTag(tag: PhotoTag, photo: CoreDataPhoto) {
        var tagsSet = Set(photo.tags ?? [])
        tagsSet.remove(tag.rawValue)
        photo.tags = Array(tagsSet)
        photo.photoListings.forEach { listing in
            removeTag(tag: tag, listing: listing)
        }
    }

    private func appendTag(tag: PhotoTag, listing: CoreDataPhotoListing) {
        let tags = CoreDataPhotoListing.tagsSerializer.deserialize(rawTags: listing.tagsRaw ?? "")
        let updatedSet = Array(Set(tags + [tag.rawValue]))
        listing.tagsRaw = CoreDataPhotoListing.tagsSerializer.serialize(tags: updatedSet)
    }

    private func removeTag(tag: PhotoTag, listing: CoreDataPhotoListing) {
        let tags = CoreDataPhotoListing.tagsSerializer.deserialize(rawTags: listing.tagsRaw ?? "")
        let updatedSet = tags.removing(tag.rawValue)
        listing.tagsRaw = CoreDataPhotoListing.tagsSerializer.serialize(tags: updatedSet)
    }
}
