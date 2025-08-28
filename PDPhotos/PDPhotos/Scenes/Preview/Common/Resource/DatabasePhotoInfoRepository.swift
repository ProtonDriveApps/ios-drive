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

final class DatabasePhotoInfoRepository: PhotoInfoRepository {
    private let observerFactory: PhotoInfoObserverFactory
    private let managedObjectContext: NSManagedObjectContext
    private var observer: FetchedResultsSectionsController<CoreDataPhoto>?
    private let photoSubject = PassthroughSubject<PhotoInfo, Never>()
    private var observerCancellable: AnyCancellable?

    var photo: AnyPublisher<PhotoInfo, Never> {
        photoSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(observerFactory: PhotoInfoObserverFactory, managedObjectContext: NSManagedObjectContext) {
        self.observerFactory = observerFactory
        self.managedObjectContext = managedObjectContext
    }

    // Fetching photo info relies on having metadata in DB
    // Metadata fetch is triggered already by other components, but this function still needs to be notified
    // once they are populated in the DB. That's why we're using observer rather than a single fetch function.
    func execute(with id: PhotoId) {
        observerCancellable = nil
        observer = nil
        observer = observerFactory.makeObserver(id: id, managedObjectContext: managedObjectContext)
        observerCancellable = observer?.objectWillChange
            .sink { [weak self] in
                self?.handleUpdate(id: id)
            }
        observer?.start()
    }

    private func handleUpdate(id: PhotoId) {
        managedObjectContext.perform { [weak self] in
            guard let self, let photo = Photo.fetch(identifier: id, in: self.managedObjectContext) else {
                Log.error("Photo with identifier:\(id) not found", error: nil, domain: .photosUI)
                return
            }

            let mimeType = MimeType(value: photo.mimeType)
            let type: PhotoInfo.PhotoType
            if mimeType.isVideo {
                type = .video
            } else if mimeType.isGif {
                type = .gif
            } else {
                type = .photo
            }
            let photoInfo = PhotoInfo(id: id, name: photo.decryptedName, type: type)
            self.photoSubject.send(photoInfo)
        }
    }
}
