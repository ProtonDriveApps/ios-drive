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

import Combine
import CoreData
import PDCore

protocol OwnPhotosRepositoryProtocol {
    var hasPhotos: AnyPublisher<Bool, Never> { get }
}

final class OwnPhotosRepository: OwnPhotosRepositoryProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let observer: FetchedResultsSectionsController<CoreDataPhotoListing>
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<Bool, Never>()
    private let backgroundQueue = DispatchQueue(label: "OwnPhotosRepository", qos: .userInteractive)

    var hasPhotos: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        observer: FetchedResultsSectionsController<CoreDataPhotoListing>,
        managedObjectContext: NSManagedObjectContext
    ) {
        self.observer = observer
        self.managedObjectContext = managedObjectContext
        subscribeToUpdates()
        backgroundQueue.async {
            observer.start()
        }
    }

    private func subscribeToUpdates() {
        observer.objectWillChange
            .throttle(for: .milliseconds(250), scheduler: backgroundQueue, latest: true)
            .map { [weak self] in
                guard let self else { return false }
                return !self.observer.isEmpty()
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasPhotos in
                self?.subject.send(hasPhotos)
            }
            .store(in: &cancellables)
    }
}
