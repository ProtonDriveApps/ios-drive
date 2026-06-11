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

import Foundation
import PDCore
import PDLocalization
import PDPhotos
import SwiftUI
import UIKit

final class DebugModeSettingsCoordinator {
    private weak var rootVC: UIViewController?
    private let backupSettingsController: PhotoBackupSettingsController
    private var localSettings: LocalSettings { tower.localSettings }
    private var storageManager: StorageManager { tower.storage }
    private let tower: Tower

    init(backupSettingsController: PhotoBackupSettingsController, tower: Tower) {
        self.backupSettingsController = backupSettingsController
        self.tower = tower
    }

    func start() -> UIViewController {
        let vm = DebugModeSettingsViewModel(localSettings: localSettings, coordinator: self)
        let vc = UIHostingController(rootView: DebugModeSettingsView(viewModel: vm))
        vc.title = Localization.setting_debug_mode
        rootVC = vc
        return vc
    }

    func showStorageDiagnostics() {
        guard let nav = rootVC?.navigationController else { return }
        let vc = StorageDiagnosticsCoordinator().start(storageManager: storageManager)
        nav.show(vc, sender: nil)
    }

    func presentPhotoBackupDiagnostics() {
        guard let nav = rootVC?.navigationController else { return }
        let diagnosticsFactory = PhotosDiagnosticsFactory()
        let diagnosticView = diagnosticsFactory.makeView(tower: tower, settingsController: backupSettingsController)
        let hostingVC = UIHostingController(rootView: diagnosticView)
        nav.present(hostingVC, animated: true)
    }
}
