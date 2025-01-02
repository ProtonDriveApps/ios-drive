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

protocol OfflineAvailableResource {
    var inProgressIds: AnyPublisher<DownloadingPhotoIds, Never> { get }
    func toggle(ids: PhotoIdsSet)
}

final class LocalOfflineAvailableResource: OfflineAvailableResource {
    private let tower: Tower
    private let downloader: Downloader
    private let storage: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private var subject = CurrentValueSubject<DownloadingPhotoIds, Never>([])
    private var cancellables = Set<AnyCancellable>()

    var inProgressIds: AnyPublisher<DownloadingPhotoIds, Never> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(tower: Tower, downloader: Downloader, storage: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.tower = tower
        self.downloader = downloader
        self.storage = storage
        self.managedObjectContext = managedObjectContext
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        downloader.downloadProcessesAndErrors()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.subscribeToUpdates()
            } receiveValue: { [weak self] trackers in
                let ids = trackers.compactMap { $0.id }
                self?.subject.send(Set(ids))
            }
            .store(in: &cancellables)
    }

    func toggle(ids: PhotoIdsSet) {
        managedObjectContext.perform { [weak self] in
            guard let self = self else { return }
            let ids = Array(ids)
            let photos = self.storage.fetchPhotos(identifiers: ids, moc: self.managedObjectContext)
            let shouldMarkOffline = photos.contains(where: { !$0.isMarkedOfflineAvailable })
            self.tower.markOfflineAvailable(shouldMarkOffline, nodes: photos, handler: { _ in })
        }
    }
}
