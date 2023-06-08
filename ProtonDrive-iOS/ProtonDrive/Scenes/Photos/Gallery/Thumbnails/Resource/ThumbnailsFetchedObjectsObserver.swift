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
import Combine
import Foundation
import PDCore

final class PhotoThumbnailsFetchedObjectsObserver: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    private let filterStrategy: ThumbnailFilterStrategy
    public var objectWillChange = ObservableObjectPublisher()
    private var cache: [Thumbnail] = []
    private var fetchedResultsController: NSFetchedResultsController<Thumbnail>

    init(fetchedResultsController: NSFetchedResultsController<Thumbnail>, filterStrategy: ThumbnailFilterStrategy) {
        self.fetchedResultsController = fetchedResultsController
        self.filterStrategy = filterStrategy
        super.init()
        fetchedResultsController.delegate = self
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        saveCache()
        objectWillChange.send()
    }

    func start() {
        do {
            try fetchedResultsController.performFetch()
        } catch let error {
            assert(false, error.localizedDescription)
        }
        objectWillChange.send()
    }

    private func saveCache() {
        fetchedResultsController.managedObjectContext.performAndWait {
            let thumbnails = fetchedResultsController.fetchedObjects ?? []
            cache = thumbnails.filter(filterStrategy.isValid)
        }
    }

    func getThumbnails() -> [Thumbnail] {
        return fetchedResultsController.managedObjectContext.performAndWait {
            return cache
        }
    }
}
