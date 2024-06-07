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
import PDCore

protocol PhotoLibraryLoadInteractor {
    var identifiers: AnyPublisher<PhotoLibraryLoadUpdate, Never> { get }
    func execute()
    func cancel()
    func suspend()
    func resume()
}

final class LocalPhotoLibraryLoadInteractor: PhotoLibraryLoadInteractor {
    private let resources: [PhotoLibraryIdentifiersResource]
    private var cancellables = Set<AnyCancellable>()
    private var subject = PassthroughSubject<PhotoLibraryLoadUpdate, Never>()

    var identifiers: AnyPublisher<PhotoLibraryLoadUpdate, Never> {
        subject.eraseToAnyPublisher()
    }

    init(resources: [PhotoLibraryIdentifiersResource]) {
        self.resources = resources
        resources.forEach(subscribe)
    }

    private func subscribe(to resource: PhotoLibraryIdentifiersResource) {
        resource.updatePublisher
            .sink { [weak self] identifiers in
                self?.subject.send(identifiers)
            }
            .store(in: &cancellables)
    }

    func execute() {
        resources.forEach { $0.execute() }
    }

    func cancel() {
        resources.forEach { $0.cancel() }
    }

    func resume() {
        resources.forEach { $0.resume() }
    }

    func suspend() {
        resources.forEach { $0.suspend() }
    }
}
