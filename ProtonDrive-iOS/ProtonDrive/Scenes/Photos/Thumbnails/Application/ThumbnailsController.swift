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
    /// Publishes only ids that are ready to be displayed
    var readyIds: AnyPublisher<PhotoIdsSet, Never> { get }
    var failedId: AnyPublisher<PhotoId, Never> { get }
    func load(_ identifier: PhotoId)
    func cancel(_ identifier: PhotoId)
}

final class LocalThumbnailsController: ThumbnailsController {
    private let thumbnailLoader: ThumbnailLoader
    private let readySubject = CurrentValueSubject<PhotoIdsSet, Never>([])
    private var cancellables = Set<AnyCancellable>()

    var readyIds: AnyPublisher<PhotoIdsSet, Never> {
        readySubject.eraseToAnyPublisher()
    }

    var failedId: AnyPublisher<PhotoId, Never> {
        thumbnailLoader.failedId.eraseToAnyPublisher()
    }

    init(thumbnailLoader: ThumbnailLoader) {
        self.thumbnailLoader = thumbnailLoader
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        thumbnailLoader.succeededId
            .sink { [weak self] id in
                guard let self = self else { return }
                var ids = self.readySubject.value
                ids.insert(id)
                self.readySubject.send(ids)
            }
            .store(in: &cancellables)
    }

    func load(_ identifier: PhotoId) {
        thumbnailLoader.loadThumbnail(with: identifier)
    }

    func cancel(_ identifier: PhotoId) {
        thumbnailLoader.cancelThumbnailLoading(identifier)
    }
}
