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

    @Published public private(set) var cache: [ResultType] = []

    public var publisher: AnyPublisher<[ResultType], Never> {
        $cache.eraseToAnyPublisher()
    }

    private var fetchedResultsController: NSFetchedResultsController<ResultType>

    public init(controller: NSFetchedResultsController<ResultType>) {
        fetchedResultsController = controller
        super.init()
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
            cache = fetchedResultsController.fetchedObjects ?? []
        } catch {
            // swiftlint:disable:next
            print("Failed to fetch items: \(error)")
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        cache = fetchedResultsController.fetchedObjects ?? []
    }
}
