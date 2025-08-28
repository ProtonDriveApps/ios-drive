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

public final class FetchedResultsControllerObserver<ResultType: NSFetchRequestResult&Equatable>: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    private var subject = PassthroughSubject<[ResultType], Never>()

    /// Subscribing to `$cache` requires you to hold reference to `FetchedResultsControllerObserver`,
    /// otherwise notifications are not delivered
    @Published public private(set) var cache: [ResultType] = []

    /// Subscribing to `getPublisher()` requires you to hold reference to `FetchedResultsControllerObserver`,
    /// otherwise notifications are not delivered
    public func getPublisher() -> AnyPublisher<[ResultType], Never> {
        $cache.eraseToAnyPublisher()
    }

    public var fetchedResultsController: NSFetchedResultsController<ResultType>

    public init(controller: NSFetchedResultsController<ResultType>, isAutomaticallyStarted: Bool = true) {
        fetchedResultsController = controller
        super.init()
        fetchedResultsController.delegate = self

        if isAutomaticallyStarted {
            start()
        }
    }

    public func start() {
        do {
            try fetchedResultsController.performFetch()
            cache = fetchedResultsController.fetchedObjects ?? []
        } catch {
            Log.error("Failed to fetch items", error: error, domain: .storage)
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        cache = fetchedResultsController.fetchedObjects ?? []
    }
}
