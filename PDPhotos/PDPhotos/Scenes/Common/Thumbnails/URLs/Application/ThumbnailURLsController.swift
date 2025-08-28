// Copyright (c) 2024 Proton AG
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
import PDCore

protocol ThumbnailURLsController {
    var readyIds: AnyPublisher<PhotoIdsSet, Never> { get }
    func load(_ identifier: PhotoId)
    func cancel(_ identifier: PhotoId)
}

/// Gathers a list of current ids and requests them via facade.
/// On facade finish update it clears current ids and publishes the update to consumers.
final class FetchingThumbnailURLsController: ThumbnailURLsController {
    private let facade: ThumbnailURLsFetchingFacade
    private var requestedIds = PhotoIdsSet()
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<PhotoIdsSet, Never>()

    var readyIds: AnyPublisher<PhotoIdsSet, Never> {
        subject.eraseToAnyPublisher()
    }

    init(facade: ThumbnailURLsFetchingFacade) {
        self.facade = facade
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        facade.finished
            .sink { [weak self] ids in
                self?.requestedIds.subtract(ids)
                self?.subject.send(ids)
            }
            .store(in: &cancellables)
    }

    func load(_ identifier: PhotoId) {
        requestedIds.insert(identifier)
        facade.execute(ids: requestedIds)
    }

    func cancel(_ identifier: PhotoId) {
        requestedIds.remove(identifier)
    }
}
