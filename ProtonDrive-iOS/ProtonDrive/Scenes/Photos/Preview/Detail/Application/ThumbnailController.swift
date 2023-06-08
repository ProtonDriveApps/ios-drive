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
import Foundation

protocol ThumbnailController {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func getImage() -> Data?
    func load()
    func cancel()
}

final class LocalThumbnailController: ThumbnailController {
    private let thumbnailsController: ThumbnailsController
    private let id: PhotoId
    private var cancellables = Set<AnyCancellable>()
    private var publisher = ObservableObjectPublisher()

    var updatePublisher: AnyPublisher<Void, Never> {
        publisher.eraseToAnyPublisher()
    }

    init(thumbnailsController: ThumbnailsController, id: PhotoId) {
        self.thumbnailsController = thumbnailsController
        self.id = id
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        thumbnailsController.updatePublisher
            .filter { [weak self] ids in
                guard let self = self else { return false }
                return ids.contains(self.id)
            }
            .sink { [weak self] _ in
                self?.handleUpdate()
            }
            .store(in: &cancellables)
    }

    func getImage() -> Data? {
        thumbnailsController.getImage(for: id)
    }

    func load() {
        thumbnailsController.load(id)
    }

    func cancel() {
        thumbnailsController.cancel(id)
    }

    private func handleUpdate() {
        if thumbnailsController.getImage(for: id) != nil {
            publisher.send()
        }
    }
}
