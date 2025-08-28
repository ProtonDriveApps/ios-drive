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
import PDLocalization
import PDPhotos

struct PhotosMigrationBannerData {
    let title: String
    let button: String
    let description: String
}

protocol PhotosMigrationBannerViewModelProtocol: ObservableObject {
    var data: PhotosMigrationBannerData? { get }
    func start()
}

final class PhotosMigrationBannerViewModel: PhotosMigrationBannerViewModelProtocol {
    private let migrationController: PhotoVolumeMigrationControllerProtocol
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private var cancellables = Set<AnyCancellable>()

    var data: PhotosMigrationBannerData?

    init(migrationController: PhotoVolumeMigrationControllerProtocol, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.migrationController = migrationController
        self.featureFlagsController = featureFlagsController
        subscribeToUpdates()
        setupData()
    }

    private func subscribeToUpdates() {
        featureFlagsController.updatePublisher
            .sink { [weak self] in
                self?.setupData()
            }
            .store(in: &cancellables)
    }

    private func setupData() {
        if featureFlagsController.hasAlbums {
            data = PhotosMigrationBannerData(
                title: Localization.photo_migration_needed_title,
                button: Localization.generic_start,
                description: Localization.photo_migration_needed_explanation
            )
        } else {
            data = nil
        }
    }

    func start() {
        migrationController.startMigration()
    }
}
