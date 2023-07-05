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

protocol FilteredPhotoIdentifiersInteractor {
    func execute(with identifiers: [PhotoIdentifier])
}

final class LocalFilteredPhotoIdentifiersInteractor: FilteredPhotoIdentifiersInteractor {
    private let resource: FilteredPhotoIdentifiersResource
    private let assetsInteractor: PhotoLibraryAssetsInteractor
    private let progressRepository: PhotoLibraryLoadProgressRepository
    private var cancellables = Set<AnyCancellable>()

    init(resource: FilteredPhotoIdentifiersResource, assetsInteractor: PhotoLibraryAssetsInteractor, progressRepository: PhotoLibraryLoadProgressRepository) {
        self.resource = resource
        self.assetsInteractor = assetsInteractor
        self.progressRepository = progressRepository
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.result
            .sink { [weak self] result in
                self?.progressRepository.discard(result.invalidIdentifiersCount)
                self?.assetsInteractor.execute(with: result.validIdentifiers)
            }
            .store(in: &cancellables)
    }

    func execute(with identifiers: [PhotoIdentifier]) {
        resource.execute(with: identifiers)
    }
}
