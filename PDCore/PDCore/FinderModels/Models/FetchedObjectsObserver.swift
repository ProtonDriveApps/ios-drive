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

import Foundation
import CoreData
import Combine

public final class FetchedObjectsObserver<ResultType: NSFetchRequestResult&Equatable>: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    public var objectWillChange = ObservableObjectPublisher()
    private var cache: [ResultType] = []
    private var fetchedResultsController: NSFetchedResultsController<ResultType>
    
    public init(_ fetchedResultsController: NSFetchedResultsController<ResultType>) {
        self.fetchedResultsController = fetchedResultsController
        super.init()
        fetchedResultsController.delegate = self
    }
    
    public func inject(fetchedResultsController: NSFetchedResultsController<ResultType>) {
        self.fetchedResultsController = fetchedResultsController
        fetchedResultsController.delegate = self
        self.start()
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let oldCache = self.cache
        if oldCache != self.fetchedObjects {
            objectWillChange.send()
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange anObject: Any,
                           at indexPath: IndexPath?,
                           for type: NSFetchedResultsChangeType,
                           newIndexPath: IndexPath?)
    {
        if indexPath?.section != newIndexPath?.section {
            objectWillChange.send()
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange sectionInfo: NSFetchedResultsSectionInfo,
                           atSectionIndex sectionIndex: Int,
                           for type: NSFetchedResultsChangeType) {
        objectWillChange.send()
    }
    
    public func start() {
        do {
            try fetchedResultsController.performFetch()
        } catch let error {
            assert(false, error.localizedDescription)
        }
        objectWillChange.send()
    }
    
    public var fetchedObjects: [ResultType] {
        // Use with caution, needs to be called on the moc's queue
        self.cache = fetchedResultsController.fetchedObjects ?? []
        return self.cache
    }

    public func getSections() -> [[ResultType]] {
        return fetchedResultsController.managedObjectContext.performAndWait {
            sections
        }
    }

    private var sections: [[ResultType]] {
        // Use with caution, needs to be called on the moc's queue
        let infos = fetchedResultsController.sections ?? []
        return infos.map {
            ($0.objects as? [ResultType]) ?? []
        }
    }
}
