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

protocol PhotoLibraryLoadProgressRepository {
    func add(_ identifiers: PhotoLibraryIds)
    func discard(_ identifiers: PhotoLibraryIds)
    func finish(_ identifiers: PhotoLibraryIds)
}

protocol PhotoLibraryLoadProgressActionRepository {
    var action: AnyPublisher<PhotoLibraryLoadAction, Never> { get }
}

enum PhotoLibraryLoadAction: Equatable {
    case added(PhotoLibraryIds)
    case discarded(PhotoLibraryIds)
    case finished(PhotoLibraryIds)
}

final class LocalPhotoLibraryLoadProgressActionRepository: PhotoLibraryLoadProgressActionRepository, PhotoLibraryLoadProgressRepository {
    private let actionSubject = PassthroughSubject<PhotoLibraryLoadAction, Never>()

    var action: AnyPublisher<PhotoLibraryLoadAction, Never> {
        actionSubject.eraseToAnyPublisher()
    }

    func add(_ identifiers: PhotoLibraryIds) {
        actionSubject.send(.added(identifiers))
    }

    func discard(_ identifiers: PhotoLibraryIds) {
        actionSubject.send(.discarded(identifiers))
    }

    func finish(_ identifiers: PhotoLibraryIds) {
        actionSubject.send(.finished(identifiers))
    }
}
