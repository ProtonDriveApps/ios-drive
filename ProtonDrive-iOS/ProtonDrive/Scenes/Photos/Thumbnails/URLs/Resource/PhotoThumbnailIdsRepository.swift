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
    func getIds(photoIds: [PhotoId], type: ThumbnailType) -> [String]
}

final class LocalPhotoThumbnailIdsRepository: PhotoThumbnailIdsRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func getIds(photoIds: [PhotoId], type: ThumbnailType) -> [String] {
        let nodeIds = photoIds.map { $0.nodeID }
        return managedObjectContext.performAndWait {
            let photos = storageManager.fetchPhotos(ids: nodeIds, moc: managedObjectContext)
            return photos.compactMap { getId(photo: $0, type: type) }
        }
    }

    private func getId(photo: Photo, type: ThumbnailType) -> String? {
        let thumbnail = photo.photoRevision.thumbnails.first(where: { $0.type == type })
        if let id = thumbnail?.id {
            return id
        } else {
            Log.error("Failed to retrieve thumbnail id.", domain: .photosUI)
            return nil
        }
    }
}
