// Copyright (c) 2025 Proton AG
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
import PDCoreIOS

protocol GalleryBannersViewModelProtocol: ObservableObject {
    var shouldShowMigration: Bool { get }
}

final class GalleryBannersViewModel: GalleryBannersViewModelProtocol {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let streamConfiguration: PhotoStreamConfiguration
    private var cancellables = Set<AnyCancellable>()

    @Published var shouldShowMigration: Bool = false

    init(featureFlagsController: FeatureFlagsControllerProtocol, streamConfiguration: PhotoStreamConfiguration) {
        self.featureFlagsController = featureFlagsController
        self.streamConfiguration = streamConfiguration
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        featureFlagsController.makePublisher(keyPath: \.hasAlbums)
            .sink { [weak self] hasAlbums in
                self?.handleUpdate(hasAlbums)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ hasAlbums: Bool) {
        shouldShowMigration = hasAlbums && streamConfiguration.isLegacyShare
    }
}
