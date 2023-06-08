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
    func execute()
    func cancel()
}

final class LocalPhotoLibraryLoadInteractor: PhotoLibraryLoadInteractor {
    private let identifiersInteractor: FilteredPhotoIdentifiersInteractor
    private let resources: [PhotoLibraryIdentifiersResource]
    private var cancellables = Set<AnyCancellable>()

    init(identifiersInteractor: FilteredPhotoIdentifiersInteractor, resources: [PhotoLibraryIdentifiersResource]) {
        self.identifiersInteractor = identifiersInteractor
        self.resources = resources
        resources.forEach(subscribe)
    }

    private func subscribe(to resource: PhotoLibraryIdentifiersResource) {
        resource.updatePublisher
            .filter { !$0.isEmpty }
            .sink { [weak self] identifiers in
                self?.identifiersInteractor.execute(with: identifiers)
            }
            .store(in: &cancellables)
    }

    func execute() {
        resources.forEach { $0.execute() }
    }

    func cancel() {
        resources.forEach { $0.cancel() }
    }
}
