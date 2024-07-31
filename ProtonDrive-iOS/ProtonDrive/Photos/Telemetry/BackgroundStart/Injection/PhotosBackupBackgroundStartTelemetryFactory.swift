// Copyright (c) 2024 Proton AG
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

struct PhotosBackupBackgroundStartTelemetryFactory {
    // swiftlint:disable:next function_parameter_count
    func makeController(telemetryController: TelemetryController, availabilityController: ComputationalAvailabilityController, backupStorage: PhotosTelemetryStorage, userInfoResource: UserInfoResource, backgroundUploadStorage: PhotosBackupBackgroundTelemetryStorageProtocol, networkController: PhotoBackupNetworkControllerProtocol) -> PhotosBackupBackgroundStartTelemetryController {
        let userInfoFactory = PhotosTelemetryFactory().makeUserInfoFactory(userInfoResource: userInfoResource)
        let dataFactory = PhotosBackupBackgroundStartTelemetryDataFactory(userInfoFactory: userInfoFactory, dateResource: PlatformCurrentDateResource(), backupStorage: backupStorage, backgroundUploadStorage: backgroundUploadStorage)
        let dateResource = PlatformCurrentDateResource()
        return PhotosBackupBackgroundStartTelemetryController(telemetryController: telemetryController, availabilityController: availabilityController, dataFactory: dataFactory, storage: backgroundUploadStorage, dateResource: dateResource)
    }
}
