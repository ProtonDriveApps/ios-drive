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
    func add(_ count: Int)
    func discard(_ count: Int)
    func finish(_ count: Int)
}

protocol PhotoLibraryLoadProgressActionRepository {
    var action: AnyPublisher<PhotoLibraryLoadAction, Never> { get }
}

enum PhotoLibraryLoadAction: Equatable {
    case added(Int)
    case discarded(Int)
    case finished(Int)
}

final class LocalPhotoLibraryLoadProgressActionRepository: PhotoLibraryLoadProgressActionRepository, PhotoLibraryLoadProgressRepository {
    private let actionSubject = PassthroughSubject<PhotoLibraryLoadAction, Never>()

    var action: AnyPublisher<PhotoLibraryLoadAction, Never> {
        actionSubject.eraseToAnyPublisher()
    }

    func add(_ count: Int) {
        actionSubject.send(.added(count))
    }

    func discard(_ count: Int) {
        actionSubject.send(.discarded(count))
    }

    func finish(_ count: Int) {
        actionSubject.send(.finished(count))
    }
}
