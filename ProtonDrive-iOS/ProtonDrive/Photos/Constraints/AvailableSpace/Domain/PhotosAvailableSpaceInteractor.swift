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

protocol PhotosAvailableSpaceInteractor {
    var constraint: AnyPublisher<Bool, Never> { get }
    func execute()
    func cancel()
}

final class ConcretePhotosAvailableSpaceInteractor: PhotosAvailableSpaceInteractor {
    private let resource: PhotosAvailableSpaceResource
    private var cancellables = Set<AnyCancellable>()
    private let constraintSubject = PassthroughSubject<Bool, Never>()

    var constraint: AnyPublisher<Bool, Never> {
        constraintSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(resource: PhotosAvailableSpaceResource) {
        self.resource = resource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.availableSpace
            .map { space in
                space < Constants.photosNecessaryFreeStorage
            }
            .removeDuplicates()
            .sink { [weak self] isConstrained in
                self?.constraintSubject.send(isConstrained)
            }
            .store(in: &cancellables)
    }

    func execute() {
        resource.execute()
    }

    func cancel() {
        resource.cancel()
    }
}
