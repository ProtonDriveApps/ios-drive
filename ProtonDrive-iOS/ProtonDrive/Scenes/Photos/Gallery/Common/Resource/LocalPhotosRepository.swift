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
    private let observer: FetchedResultsSectionsController<Photo>
    private let mimeTypeResource: MimeTypeResource
    private let offlineAvailableResource: OfflineAvailableResource
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<[PhotosSection], Never>()
    private let backgroundQueue = DispatchQueue(label: "LocalPhotosRepository", qos: .userInteractive)

    private var managedObjectContext: NSManagedObjectContext {
        observer.managedObjectContext
    }

    var updatePublisher: AnyPublisher<[PhotosSection], Never> {
        subject.eraseToAnyPublisher()
    }

    init(observer: FetchedResultsSectionsController<Photo>, mimeTypeResource: MimeTypeResource, offlineAvailableResource: OfflineAvailableResource) {
        self.observer = observer
        self.mimeTypeResource = mimeTypeResource
        self.offlineAvailableResource = offlineAvailableResource
        subscribeToUpdates()
        backgroundQueue.async { [weak self] in
            self?.observer.start()
        }
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(observer.objectWillChange, offlineAvailableResource.inProgressIds)
            .throttle(for: .milliseconds(250), scheduler: backgroundQueue, latest: true)
            .map { [weak self] update -> [PhotosSection] in
                guard let self = self else { return [] }
                let sections = self.observer.getSections()
                return sections.compactMap { self.makeSection(from: $0, downloadingIds: update.1) }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                self?.subject.send(sections)
            }
            .store(in: &cancellables)
    }

    private func makeSection(from photos: [Photo], downloadingIds: DownloadingPhotoIds) -> PhotosSection? {
        return managedObjectContext.performAndWait {
            let models = photos.compactMap { makePhoto(from: $0, downloadingIds: downloadingIds) }
            guard !models.isEmpty else {
                return nil
            }
            guard let month = getMonth(from: photos) else {
                return nil
            }
            return PhotosSection(month: month, photos: models)
        }
    }

    private func getMonth(from photos: [Photo]) -> Date? {
        guard let firstPhoto = photos.first(where: { $0.managedObjectContext != nil }) else {
            return nil
        }
        return firstPhoto.captureTime
    }

    private func makePhoto(from photo: Photo, downloadingIds: DownloadingPhotoIds) -> PhotosSection.Photo? {
        guard photo.managedObjectContext != nil else { return nil }
        let isVideo = mimeTypeResource.isVideo(mimeType: photo.mimeType)
        return PhotosSection.Photo(
            id: photo.identifier,
            isShared: photo.isShared,
            hasDirectShare: photo.hasDirectShare,
            isVideo: isVideo,
            captureTime: photo.captureTime,
            isAvailableOffline: photo.isMarkedOfflineAvailable && photo.isDownloaded,
            isDownloading: photo.isMarkedOfflineAvailable && downloadingIds.contains(photo.id),
            burstChildrenCount: photo.canBeBurstPhoto ? photo.children.count : nil
        )
    }
}
