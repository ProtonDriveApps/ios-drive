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

// swiftlint:disable empty_count
final class LocalPhotoLibraryLoadProgressActionRepository: PhotoLibraryLoadProgressActionRepository, PhotoLibraryLoadProgressRepository {
    private let actionSubject = PassthroughSubject<PhotoLibraryLoadAction, Never>()
    private let queue = DispatchQueue(label: "LocalPhotoLibraryLoadProgressActionRepository", qos: .default)

    var action: AnyPublisher<PhotoLibraryLoadAction, Never> {
        actionSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func add(_ count: Int) {
        guard count != 0 else { return }
        queue.sync {
            actionSubject.send(.added(count))
        }
    }

    func discard(_ count: Int) {
        guard count != 0 else { return }
        queue.sync {
            actionSubject.send(.discarded(count))
        }
    }

    func finish(_ count: Int) {
        guard count != 0 else { return }
        queue.sync {
            actionSubject.send(.finished(count))
        }
    }

    func reset() {
        queue.sync {
            actionSubject.send(.reset)
        }
    }
}
// swiftlint:enable empty_count
