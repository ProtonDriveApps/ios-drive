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

import ProtonCore_Settings
import SwiftUI
import UIKit

struct PhotosSettingsFactory {
    func makeSettingsCell(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        bootstrapController: PhotosBootstrapController
    ) -> PMCellSuplier {
        let viewModel = PhotosSettingsRowViewModel(settingsController: settingsController)
        return PMDrillDownConfiguration(viewModel: viewModel) {
            makeSettingsView(settingsController: settingsController, authorizationController: authorizationController, bootstrapController: bootstrapController)
        }
    }

    private func makeSettingsView(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        bootstrapController: PhotosBootstrapController
    ) -> UIViewController {
        let factory = PhotosSettingsFactory()
        let startController = LocalPhotosBackupStartController(settingsController: settingsController, authorizationController: authorizationController, photosBootstrapController: bootstrapController)
        let viewModel = PhotosSettingsViewModel(settingsController: settingsController, startController: startController)
        let view = PhotosSettingsView(viewModel: viewModel)
        return UIHostingController(rootView: view)
    }
}
