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

protocol PhotosListFilterResource {
    func filter(_ list: PhotosList) -> PhotosList
}

final class CoreDataPhotosListFilterResource: PhotosListFilterResource {
    private let storage: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(storage: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.storage = storage
        self.managedObjectContext = managedObjectContext
    }

    func filter(_ list: PhotosList) -> PhotosList {
        let ids = list.photos.map { $0.linkId }
        return managedObjectContext.performAndWait {
            let photoIds = storage.fetchPhotos(ids: ids, moc: managedObjectContext).map { $0.id }
            let photos = list.photos.filter { !photoIds.contains($0.linkId) }
            return PhotosList(photos: photos)
        }
    }
}
