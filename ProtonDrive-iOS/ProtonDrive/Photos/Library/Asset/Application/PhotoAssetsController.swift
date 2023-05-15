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

protocol PhotoAssetsController {
    var error: AnyPublisher<Error, Never> { get }
}

// TODO: should react to low local storage or try processing assets in batches?
final class LocalPhotoAssetsController: PhotoAssetsController {
    private let interactor: PhotoLibraryAssetsInteractor
    private let errorSubject = PassthroughSubject<Error, Never>()
    private var cancellables = Set<AnyCancellable>()

    var error: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(interactor: PhotoLibraryAssetsInteractor) {
        self.interactor = interactor
        interactor.error
            .sink { [weak self] error in
                self?.errorSubject.send(error)
            }
            .store(in: &cancellables)
    }
}
