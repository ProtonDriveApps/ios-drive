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

import Foundation
import CoreData
import Combine
import PDCore

public protocol VolumeIdObserver {
    var volumeIdPublisher: AnyPublisher<VolumeID, Never> { get }
}

public final class PhotosVolumeIdObserver: VolumeIdObserver {

    private let frcObserver: FetchedResultsControllerObserver<Volume>
    private let storageManager: StorageManager
    private let volumeIdSubject = CurrentValueSubject<VolumeID, Never>("")
    private var cancellables: Set<AnyCancellable> = []

    public var volumeIdPublisher: AnyPublisher<VolumeID, Never> {
        volumeIdSubject
            .filter { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public init(storageManager: StorageManager) {
        self.storageManager = storageManager
        let request: NSFetchRequest<Volume> = storageManager.requestVolumes(type: .photo)
        request.fetchLimit = 1

        let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: storageManager.backgroundContext, sectionNameKeyPath: nil, cacheName: nil)
        let observer = FetchedResultsControllerObserver(controller: frc, isAutomaticallyStarted: true)
        self.frcObserver = observer

        observer
            .getPublisher()
            .sink { [weak self] volumes in
                guard let self else { return }
                storageManager.backgroundContext.perform {
                    guard let volume = volumes.first else {
                        return
                    }
                    self.volumeIdSubject.send(volume.id)
                }
            }
            .store(in: &cancellables)
    }
}
