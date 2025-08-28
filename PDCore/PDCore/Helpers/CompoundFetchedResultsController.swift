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
import Combine

// The usual fetched results observer, with the addition of notifying when related entity notifies
// Should be used for observing objects which need to be updated when related object changes some of their attributes
// Disclaimer: the structure expects the primary entity to have a relationship to the secondary
public final class CompoundFetchedResultsController<PrimaryType: NSFetchRequestResult, SecondaryType: NSFetchRequestResult>: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    public var objectWillChange = ObservableObjectPublisher()
    private var primaryController: NSFetchedResultsController<PrimaryType>
    private var secondaryController: NSFetchedResultsController<SecondaryType>

    private var managedObjectContext: NSManagedObjectContext {
        primaryController.managedObjectContext
    }

    public init(primaryController: NSFetchedResultsController<PrimaryType>, secondaryController: NSFetchedResultsController<SecondaryType>) {
        self.primaryController = primaryController
        self.secondaryController = secondaryController
        super.init()
        primaryController.delegate = self
        secondaryController.delegate = self
    }

    public func start() {
        do {
            try primaryController.performFetch()
            try secondaryController.performFetch()
        } catch let error {
            Log.error(error: error, domain: .storage)
        }
        objectWillChange.send()
    }

    public func getSections() -> [[PrimaryType]] {
        return managedObjectContext.performAndWait {
            let infos = primaryController.sections ?? []
            return infos.map {
                ($0.objects as? [PrimaryType]) ?? []
            }
        }
    }

    public func getObjects() -> [PrimaryType] {
        return managedObjectContext.performAndWait {
            return primaryController.fetchedObjects ?? []
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objectWillChange.send()
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if controller == primaryController || (controller == secondaryController && type == .update) {
            objectWillChange.send()
        }
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        if controller == primaryController || (controller == secondaryController && type == .update) {
            objectWillChange.send()
        }
    }
}
