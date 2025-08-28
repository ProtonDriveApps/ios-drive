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
import PMSettings
import PDLocalization
import PDPhotos

final class PhotosSettingsRowViewModel: PMDrillDownCellViewModel {
    private let settingsController: PhotoBackupSettingsController
    private let warningViewModel: PhotosMigrationWarningViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    private var value: String?

    init(settingsController: PhotoBackupSettingsController, warningViewModel: PhotosMigrationWarningViewModelProtocol) {
        self.settingsController = settingsController
        self.warningViewModel = warningViewModel
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        settingsController.isEnabled.combineLatest(warningViewModel.warning)
            .map { isEnabled, warning in
                let shouldEnable = isEnabled && warning == nil
                return shouldEnable ? Localization.general_on : Localization.general_off
            }
            .sink { [weak self] value in
                self?.value = value
            }
            .store(in: &cancellables)
    }

    var preview: String? {
        value
    }

    var title: String {
        Localization.setting_photo_backup
    }
    
    var accessibilityIdentifier: String { Localization.setting_photo_backup }
}
