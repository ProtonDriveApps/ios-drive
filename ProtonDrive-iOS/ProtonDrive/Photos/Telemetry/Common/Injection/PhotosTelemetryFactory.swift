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

struct PhotosTelemetryFactory {
    func makeSettingController(tower: Tower, settingsController: PhotoBackupSettingsController, telemetryController: TelemetryController) -> PhotosTelemetrySettingController {
        let userInfoFactory = makeUserInfoFactory(userInfoResource: tower.sessionVault)
        return ConcretePhotosTelemetrySettingController(telemetryController: telemetryController, settingsController: settingsController, userInfoFactory: userInfoFactory)
    }

    func makeStopController(tower: Tower, stateController: PhotosBackupStateController, telemetryController: TelemetryController, storage: PhotosTelemetryStorage, loadController: PhotoLibraryLoadController) -> PhotosBackupStopTelemetryController {
        let durationController = makeDurationController(backupStateController: stateController, storage: storage)
        let userInfoFactory = makeUserInfoFactory(userInfoResource: tower.sessionVault)
        let dataFactory = ConcretePhotosBackupStopTelemetryDataFactory(storage: storage, userInfoFactory: userInfoFactory)
        return ConcretePhotosBackupStopTelemetryController(stateController: stateController, telemetryController: telemetryController, durationController: durationController, dataFactory: dataFactory, storage: storage, loadController: loadController)
    }

    func makeUserInfoFactory(userInfoResource: UserInfoResource) -> PhotosTelemetryUserInfoFactory {
        ConcretePhotosTelemetryUserInfoFactory(userInfoResource: userInfoResource)
    }

    private func makeDurationController(backupStateController: PhotosBackupStateController, storage: PhotosTelemetryStorage) -> PhotosBackupDurationController {
        return SavingPhotosBackupDurationController(backupStateController: backupStateController, dateResource: PlatformCurrentDateResource(), storage: storage)
    }
}
