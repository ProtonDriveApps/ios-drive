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

protocol PhotosTelemetrySettingController {}

final class ConcretePhotosTelemetrySettingController: PhotosTelemetrySettingController {
    private let telemetryController: TelemetryController
    private let settingsController: PhotoBackupSettingsController
    private let userInfoFactory: PhotosTelemetryUserInfoFactory
    private var cancellables = Set<AnyCancellable>()

    init(telemetryController: TelemetryController, settingsController: PhotoBackupSettingsController, userInfoFactory: PhotosTelemetryUserInfoFactory) {
        self.telemetryController = telemetryController
        self.settingsController = settingsController
        self.userInfoFactory = userInfoFactory
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        settingsController.isEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.handleUpdate(isEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(isEnabled: Bool) {
        let data = TelemetryData(
            group: .photos,
            event: isEnabled ? .settingEnabled : .settingDisabled,
            dimensions: userInfoFactory.makeDimensions()
        )
        telemetryController.send(data: data)
    }
}
