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

public final class FetchedResultsSectionsController<ResultType: NSFetchRequestResult&Equatable>: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    public var objectWillChange = ObservableObjectPublisher()
    private var controller: NSFetchedResultsController<ResultType>
    public var managedObjectContext: NSManagedObjectContext {
        controller.managedObjectContext
    }

    public init(controller: NSFetchedResultsController<ResultType>) {
        self.controller = controller
        super.init()
        controller.delegate = self
    }

    public func start() {
        do {
            try controller.performFetch()
        } catch let error {
            Log.error("Starting fecthedResultsSectionsController failed", error: error, domain: .storage)
        }
        objectWillChange.send()
    }

    public func getSections() -> [[ResultType]] {
        return controller.managedObjectContext.performAndWait {
            let infos = controller.sections ?? []
            return infos.map {
                ($0.objects as? [ResultType]) ?? []
            }
        }
    }

    public func getObjects() -> [ResultType] {
        return controller.managedObjectContext.performAndWait {
            return controller.fetchedObjects ?? []
        }
    }

    public func isEmpty() -> Bool {
        return controller.managedObjectContext.performAndWait {
            return controller.fetchedObjects?.isEmpty ?? true
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objectWillChange.send()
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        objectWillChange.send()
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        objectWillChange.send()
    }
}
