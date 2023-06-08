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
import PDCore

typealias PhotoId = NodeIdentifier
typealias PhotoIdsSet = Set<PhotoId>

protocol ThumbnailsController: AnyObject {
    var updatePublisher: AnyPublisher<PhotoIdsSet, Never> { get }
    func getImage(for photoId: PhotoId) -> Data?
    func load(_ identifier: PhotoId)
    func cancel(_ identifier: PhotoId)
}

final class LocalThumbnailsController: ThumbnailsController {
    private let repository: ThumbnailsRepository
    private let thumbnailLoader: ThumbnailLoader
    private let identifiersSubject = CurrentValueSubject<PhotoIdsSet, Never>([])
    private var cancellables = Set<AnyCancellable>()

    var updatePublisher: AnyPublisher<PhotoIdsSet, Never> {
        identifiersSubject.eraseToAnyPublisher()
    }

    init(repository: ThumbnailsRepository, thumbnailLoader: ThumbnailLoader) {
        self.repository = repository
        self.thumbnailLoader = thumbnailLoader
        repository.updatePublisher
            .sink { [weak self] identifiers in
                self?.identifiersSubject.send(identifiers)
            }
            .store(in: &cancellables)
    }

    func getImage(for photoId: PhotoId) -> Data? {
        guard identifiersSubject.value.contains(photoId) else {
            return nil
        }
        return repository.getData(for: photoId)
    }

    func load(_ identifier: PhotoId) {
        thumbnailLoader.loadThumbnail(with: identifier)
    }

    func cancel(_ identifier: PhotoId) {
        thumbnailLoader.cancelThumbnailLoading(identifier)
    }
}
