// Copyright (c) 2023 Proton AG
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

final class DatabasePhotosTrashRepository: LocalPhotosTrashRepository {
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        managedObjectContext = storageManager.photosSecondaryBackgroundContext
    }

    func trash(with identifiers: [PhotoId]) async throws {
        try await managedObjectContext.perform {
            let photos = self.storageManager.fetchPhotos(identifiers: identifiers, moc: self.managedObjectContext)
            photos.forEach { photo in
                self.trashPhoto(photo)
                photo.children.forEach(self.trashPhoto)
            }
            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func trashPhoto(_ photo: CoreDataPhoto) {
        photo.state = .deleted
        // Listings need to be deleted immediately to propagate the change to UI.
        photo.photoListings.forEach { managedObjectContext.delete($0) }
    }
}
