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

protocol PhotosTabVisibleController {
    var isEnabled: AnyPublisher<Bool, Never> { get }
}

final class ConcretePhotosTabVisibleController: PhotosTabVisibleController {
    private let resource: FeatureFlagsRepository
    private let subject: CurrentValueSubject<Bool, Never>
    private var cancellables = Set<AnyCancellable>()

    var isEnabled: AnyPublisher<Bool, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(resource: FeatureFlagsRepository) {
        self.resource = resource
        subject = .init(resource.isEnabled(flag: .photosEnabled))
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.updatePublisher
            .map { [weak self] in
                self?.resource.isEnabled(flag: .photosEnabled) ?? false
            }
            .sink { [weak self] value in
                self?.subject.send(value)
            }
            .store(in: &cancellables)
    }
}
