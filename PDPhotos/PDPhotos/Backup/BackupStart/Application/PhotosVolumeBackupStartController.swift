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

/// Used from outside of photos, so apart from settings enabled flag and authorizations, we also need
/// to make sure to bootstrap a photo share.
/// Either via new photos volume, or via the legacy bootstrap (both ways handled by `PhotoVolumeBootstrapControllerProtocol`)
final class PhotosVolumeBackupStartController: PhotosBackupStartController {
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let volumeBootstrapController: PhotoVolumeBootstrapControllerProtocol

    init(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        volumeBootstrapController: PhotoVolumeBootstrapControllerProtocol
    ) {
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        self.volumeBootstrapController = volumeBootstrapController
    }

    func start() {
        settingsController.setEnabled(true)
        authorizationController.authorize()
        volumeBootstrapController.bootstrap()
    }
}
