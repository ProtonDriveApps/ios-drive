// Copyright (c) 2024 Proton AG
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

protocol PhotoThumbnailIdsRepository {
    func getIds(photoIds: [PhotoId], type: ThumbnailType) -> [AnyVolumeIdentifier]
}

final class LocalPhotoThumbnailIdsRepository: PhotoThumbnailIdsRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func getIds(photoIds: [PhotoId], type: ThumbnailType) -> [AnyVolumeIdentifier] {
        return managedObjectContext.performAndWait {
            let photos = Photo.fetch(identifiers: Set(photoIds), in: managedObjectContext)
            return photos.compactMap { getId(photo: $0, type: type) }
        }
    }

    private func getId(photo: Photo, type: ThumbnailType) -> AnyVolumeIdentifier? {
        let thumbnail = photo.photoRevision.thumbnails.first(where: { $0.type == type })

        guard let id = thumbnail?.id else {
            var context = LogContext(photo.genericIdentifierWithinManagedObjectContext.debugDesc, forKey: "photoID")
            context["thumbnailCount"] = photo.photoRevision.thumbnails.count.description
            Log.error("Failed to retrieve \(type.description) thumbnail id.", error: nil, domain: .thumbnails, context: context)
            return nil
        }

        guard !id.isEmpty else {
            var context = LogContext(photo.genericIdentifier.debugDesc, forKey: "photoID")
            context["revisionID"] = photo.photoRevision.id
            Log.error("Getting empty thumbnailId", error: nil, domain: .thumbnails, context: context)
            assertionFailure("Should not happen, photo: \(photo.identifier), revision: \(photo.photoRevision.id)")
            return nil
        }

        return AnyVolumeIdentifier(id: id, volumeID: photo.volumeID)
    }
}
