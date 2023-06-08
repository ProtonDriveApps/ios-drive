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

protocol FilteredPhotoCompoundsInteractor {
    func execute(with compounds: [PhotoAssetCompound])
}

final class LocalFilteredPhotoCompoundsInteractor: FilteredPhotoCompoundsInteractor {
    private let resource: FilteredPhotoCompoundsResource
    private let importInteractor: PhotoImportInteractor
    private var cancellables = Set<AnyCancellable>()

    init(resource: FilteredPhotoCompoundsResource, importInteractor: PhotoImportInteractor) {
        self.resource = resource
        self.importInteractor = importInteractor
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.result
            .sink { [weak self] compounds in
                self?.importInteractor.execute(with: compounds)
            }
            .store(in: &cancellables)
    }

    func execute(with compounds: [PhotoAssetCompound]) {
        resource.execute(with: compounds)
    }
}
