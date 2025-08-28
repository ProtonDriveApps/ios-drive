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

import Combine
import PDCore

protocol FavoritingControllerProtocol {
    var result: AnyPublisher<FavoritingResult, Never> { get }
    func toggle(ids: PhotoIdsSet)
}

final class FavoritingController: FavoritingControllerProtocol {
    private let facade: FavoritingFacadeProtocol
    private var cancellables = Set<AnyCancellable>()
    private let resultSubject = PassthroughSubject<FavoritingResult, Never>()

    var result: AnyPublisher<FavoritingResult, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    init(facade: FavoritingFacadeProtocol) {
        self.facade = facade
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        facade.result
            .sink { [weak self] result in
                self?.resultSubject.send(result)
            }
            .store(in: &cancellables)
    }

    func toggle(ids: PhotoIdsSet) {
        facade.execute(with: ids)
    }
}
