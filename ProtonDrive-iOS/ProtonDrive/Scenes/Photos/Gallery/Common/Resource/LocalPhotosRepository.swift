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

import Combine
import CoreData
import PDCore

final class LocalPhotosRepository: PhotosRepository {
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private let observer: FetchedObjectsObserver<Photo>
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<[PhotosSection], Never>()
    private let backgroundQueue = DispatchQueue(label: "LocalPhotosRepository", qos: .userInteractive)

    var updatePublisher: AnyPublisher<[PhotosSection], Never> {
        subject.eraseToAnyPublisher()
    }

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        managedObjectContext = storageManager.backgroundContext
        let fetchedController = storageManager.subscriptionToPrimaryUploadedPhotos(moc: managedObjectContext)
        observer = FetchedObjectsObserver(fetchedController)
        subscribeToUpdates()
        observer.start()
    }

    private func subscribeToUpdates() {
        observer.objectWillChange
            .receive(on: backgroundQueue)
            .map { [weak self] in
                guard let self = self else { return [] }
                let sections = self.observer.getSections()
                return sections.compactMap { self.makeSection(from: $0) }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                self?.subject.send(sections)
            }
            .store(in: &cancellables)
    }

    private func makeSection(from photos: [Photo]) -> PhotosSection? {
        return managedObjectContext.performAndWait {
            let models = photos.map(makePhoto)
            guard !models.isEmpty else {
                return nil
            }
            return PhotosSection(month: photos[0].captureTime, photos: models)
        }
    }

    private func makePhoto(from photo: Photo) -> PhotosSection.Photo {
        let duration = makeDuration(from: photo)
        return PhotosSection.Photo(id: photo.identifier, duration: duration)
    }

    private func makeDuration(from photo: Photo) -> UInt? {
        let duration = try? photo.photoRevision.decryptExtendedAttributes().media?.duration
        return duration.map { UInt($0) }
    }
}
