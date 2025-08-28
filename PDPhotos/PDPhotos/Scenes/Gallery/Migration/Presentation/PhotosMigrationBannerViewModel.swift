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
import PDLocalization
import PDCoreIOS

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
    private let streamConfiguration: PhotoStreamConfiguration
    private var cancellables = Set<AnyCancellable>()

    var data: PhotosMigrationBannerData?

    init(migrationController: PhotoVolumeMigrationControllerProtocol, featureFlagsController: FeatureFlagsControllerProtocol, streamConfiguration: PhotoStreamConfiguration) {
        self.migrationController = migrationController
        self.featureFlagsController = featureFlagsController
        self.streamConfiguration = streamConfiguration
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
        if shouldShowData() {
            data = PhotosMigrationBannerData(
                title: Localization.photo_migration_needed_title,
                button: Localization.generic_start,
                description: Localization.photo_migration_needed_explanation
            )
        } else {
            data = nil
        }
    }

    private func shouldShowData() -> Bool {
        return featureFlagsController.hasAlbums && streamConfiguration.isLegacyShare
    }

    func start() {
        migrationController.startMigration()
    }
}
