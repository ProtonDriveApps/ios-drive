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
import Foundation
import PDCore

final class DatabasePhotoUploadsRepository: PhotoUploadsRepository {
    private let storage: StorageManager
    private var observer: FetchedResultsControllerObserver<Photo>?
    private var observerCancellable: AnyCancellable?
    private let backgroundQueue = DispatchQueue.global(qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<PhotosUploadingCount, Never>()
    private let photosMoc: NSManagedObjectContext
    private var isInitialCount: Bool = true

    var count: AnyPublisher<PhotosUploadingCount, Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        isBackupAvailable: PhotosBackupUploadAvailableController,
        photosMoc: NSManagedObjectContext,
        storage: StorageManager
    ) {
        self.photosMoc = photosMoc
        self.storage = storage
        isBackupAvailable.isAvailable
            .receive(on: backgroundQueue)
            .sink { [weak self] isAvailable in
                if isAvailable {
                    self?.setupObserver()
                } else {
                    self?.stopObserver()
                }
            }
            .store(in: &cancellables)
    }

    private func setupObserver() {
        let observer = FetchedResultsControllerObserver(
            controller: storage.subscriptionToMyPrimaryUploadingPhotosCount(moc: photosMoc),
            isAutomaticallyStarted: false
        )
        self.observer = observer
        subscribeToUpdates()
        // Start can be heavy in case of many objects. Shouldn't be performed on main queue.
        // Initial count needs to be notified as a special case so the upload counters are correctly set up.
        observer.start()
        notifyInitialCount()
    }

    private func stopObserver() {
        observer = nil
        observerCancellable = nil
    }

    private func notifyInitialCount() {
        let count = observer?.cache.count ?? 0
        DispatchQueue.main.async { [weak self] in
            let count = PhotosUploadingCount(count: count, isInitialCount: true)
            self?.subject.send(count)
        }
    }

    private func subscribeToUpdates() {
        observerCancellable = observer?.photos
            .map { photos in
                photos.count
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                let uploadingCount = PhotosUploadingCount(count: count, isInitialCount: false)
                self?.subject.send(uploadingCount)
            }
    }
}
