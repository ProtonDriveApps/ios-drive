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

protocol PhotosSettingsViewModelProtocol: ObservableObject {
    var title: String { get }
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool)
}

final class PhotosSettingsViewModel: PhotosSettingsViewModelProtocol {
    private let settingsController: PhotoBackupSettingsController
    private let startController: PhotosBackupStartController

    let title = "Photos backup"
    @Published var isEnabled = false

    init(settingsController: PhotoBackupSettingsController, startController: PhotosBackupStartController) {
        self.settingsController = settingsController
        self.startController = startController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        settingsController.isEnabled
            .assign(to: &$isEnabled)
    }

    func setEnabled(_ isEnabled: Bool) {
        if isEnabled {
            startController.start()
        } else {
            settingsController.setEnabled(isEnabled)
        }
    }
}
