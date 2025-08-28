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

import PDCore
import PMSettings
import SwiftUI
import UIKit
import PDPhotos

struct PhotosSettingsFactory {
    func makeSettingsCell(
         settingsController: PhotoBackupSettingsController,
         tower: Tower,
         backupStartController: PhotosBackupStartController,
         migrationController: PhotoVolumeMigrationControllerProtocol
    ) -> PMCellSuplier {
        let warningViewModel = PhotosMigrationWarningViewModel(controller: migrationController)
        let viewModel = PhotosSettingsRowViewModel(
            settingsController: settingsController,
            warningViewModel: warningViewModel
        )
        return PMDrillDownConfiguration(viewModel: viewModel) {
            makeSettingsView(
                settingsController: settingsController,
                tower: tower,
                backupStartController: backupStartController,
                warningViewModel: warningViewModel
            )
        }
    }

    private func makeSettingsView(
        settingsController: PhotoBackupSettingsController,
        tower: Tower,
        backupStartController: PhotosBackupStartController,
        warningViewModel: PhotosMigrationWarningViewModelProtocol
    ) -> UIViewController {

        let viewModel = PhotosSettingsViewModel(
            settingsController: settingsController,
            startController: backupStartController,
            localSettings: tower.localSettings,
            warningViewModel: warningViewModel,
            b2bSettingsUpdateDataSource: tower.client
        )
        if Constants.buildType.isQaOrBelow {
            let diagnosticsFactory = PhotosDiagnosticsFactory()
            let diagnosticView = diagnosticsFactory.makeView(tower: tower, settingsController: settingsController)
            let qaSettingsViewModel = PhotosSettingsQAViewModel(settingsController: settingsController)
            let qaSettingsView = PhotosSettingsQAView(viewModel: qaSettingsViewModel, diagnosticsView: diagnosticView)
            let view = PhotosSettingsView(viewModel: viewModel, qaSettingsView: qaSettingsView)
            return UIHostingController(rootView: view)
        } else {
            let view = PhotosSettingsView(viewModel: viewModel, qaSettingsView: EmptyView())
            return UIHostingController(rootView: view)
        }
    }
}
