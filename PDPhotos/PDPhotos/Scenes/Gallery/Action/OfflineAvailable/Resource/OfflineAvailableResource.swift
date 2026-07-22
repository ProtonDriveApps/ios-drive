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
    var inProgressIds: AnyPublisher<PhotoIdsSet, Never> { get }
    func toggle(ids: PhotoIdsSet)
}

final class LocalOfflineAvailableResource: OfflineAvailableResource {
    private let tower: Tower
    private let downloader: Downloader
    private let sdkDownloader: SDKFileDownloaderProtocol?
    private let storage: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private var subject = CurrentValueSubject<PhotoIdsSet, Never>([])
    private var cancellables = Set<AnyCancellable>()

    var inProgressIds: AnyPublisher<PhotoIdsSet, Never> {
        subject.eraseToAnyPublisher()
    }

    init(tower: Tower, downloader: Downloader, sdkDownloader: SDKFileDownloaderProtocol?, storage: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.tower = tower
        self.downloader = downloader
        self.sdkDownloader = sdkDownloader
        self.storage = storage
        self.managedObjectContext = managedObjectContext
        Task { @MainActor in
            subscribeToUpdates()
        }
    }

    @MainActor
    private func subscribeToUpdates() {
        sdkDownloader?.progresses
            .map { Set($0.keys) }
            .eraseToAnyPublisher()
            .sink { [weak self] ids in
                self?.subject.send(ids)
            }
            .store(in: &cancellables)
    }

    func toggle(ids: PhotoIdsSet) {
        managedObjectContext.perform { [weak self] in
            guard let self = self else { return }
            let ids = Array(ids)
            let photos = self.storage.fetchPhotos(identifiers: ids, moc: self.managedObjectContext)
            let shouldMarkOffline = photos.contains(where: { !$0.isMarkedOfflineAvailable })
            self.tower.markOfflineAvailable(shouldMarkOffline, nodes: photos, moc: managedObjectContext) { [weak self] _ in
                self?.notifyUpdate()
            }
        }
    }

    private func notifyUpdate() {
        // Post a notification immediately so the UI can reflect the latest state
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let value = self.subject.value
            self.subject.send(value)
        }
    }
}
