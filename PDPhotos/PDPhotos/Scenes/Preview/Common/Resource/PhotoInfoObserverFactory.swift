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

struct PhotoInfoObserverFactory {
    func makeObserver(id: PhotoId, managedObjectContext: NSManagedObjectContext) -> FetchedResultsSectionsController<CoreDataPhoto> {
        let fetchedController = makeFetchedResultsController(id: id, managedObjectContext: managedObjectContext)
        return FetchedResultsSectionsController(controller: fetchedController)
    }

    private func makeFetchedResultsController(id: PhotoId, managedObjectContext: NSManagedObjectContext) -> NSFetchedResultsController<CoreDataPhoto> {
        return NSFetchedResultsController(
            fetchRequest: makeFetchRequest(id: id),
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    private func makeFetchRequest(id: PhotoId) -> NSFetchRequest<CoreDataPhoto> {
        let fetchRequest = Photo.fetchRequest(id: id.id, volumeID: id.volumeID, allowSubclasses: true)
        // NSFetchedResultsController requires sortDescriptor
        fetchRequest.sortDescriptors = [.init(key: #keyPath(CoreDataPhoto.id), ascending: true)]
        return fetchRequest
    }
}
