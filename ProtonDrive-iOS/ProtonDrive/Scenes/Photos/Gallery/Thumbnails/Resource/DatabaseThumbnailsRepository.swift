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
import PDCore

final class DatabaseThumbnailsRepository: ThumbnailsRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let observer: PhotoThumbnailsFetchedObjectsObserver
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<PhotoIdsSet, Never>([])
    private let backgroundQueue = DispatchQueue(label: "DatabaseThumbnailsRepository", qos: .userInteractive)

    var updatePublisher: AnyPublisher<PhotoIdsSet, Never> {
        subject.eraseToAnyPublisher()
    }

    init(managedObjectContext: NSManagedObjectContext, observer: PhotoThumbnailsFetchedObjectsObserver) {
        self.managedObjectContext = managedObjectContext
        self.observer = observer
        subscribeToUpdates()
    }

    func getData(for photoId: PhotoId) -> Data? {
        return managedObjectContext.performAndWait {
            observer.getThumbnails().first(where: {
                ($0.revision as? PhotoRevision)?.photo.identifier == photoId
            })?.clearData
        }
    }

    private func subscribeToUpdates() {
        observer.objectWillChange
            .receive(on: backgroundQueue)
            .map { [weak self] in
                self?.getDownloadedIds() ?? []
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] thumbnails in
                self?.subject.send(thumbnails)
            }
            .store(in: &cancellables)
        observer.start()
    }

    private func getDownloadedIds() -> Set<PhotoId> {
        let thumbnails = observer.getThumbnails()
        return Set(thumbnails.compactMap(getPhotoId))
    }

    private func getPhotoId(from thumbnail: Thumbnail) -> PhotoId? {
        return managedObjectContext.performAndWait {
            guard let revision = thumbnail.revision as? PhotoRevision else {
                return nil
            }

            guard thumbnail.clearData != nil else {
                return nil
            }

            return revision.photo.identifier
        }
    }
}
