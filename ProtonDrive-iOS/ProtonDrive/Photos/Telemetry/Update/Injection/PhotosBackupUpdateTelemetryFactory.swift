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

struct PhotosBackupUpdateTelemetryFactory {
    // swiftlint:disable:next function_parameter_count
    func makeController(telemetryController: TelemetryController, stateController: PhotosBackupStateController, storage: PhotosTelemetryStorage, userInfoResource: UserInfoResource, uploadRepository: DurationMeasurementRepository, scanningRepository: DurationMeasurementRepository, duplicatesRepository: DurationMeasurementRepository, throttlingRepository: DurationMeasurementRepository) -> PhotosBackupUpdateTelemetryController {
        let duration = Constants.Metrics.photosBackupHeartbeatInterval
        let valuesRepository = ConcretePhotosBackupUpdateValuesRepository(uploadRepository: uploadRepository, scanningRepository: scanningRepository, duplicatesRepository: duplicatesRepository, throttlingRepository: throttlingRepository, storage: storage, duration: duration)
        let userInfoFactory = PhotosTelemetryFactory().makeUserInfoFactory(userInfoResource: userInfoResource)
        return ConcretePhotosBackupUpdateTelemetryController(telemetryController: telemetryController, stateController: stateController, valuesRepository: valuesRepository, timerResource: CommonRunLoopPausableTimerResource(duration: duration), dataFactory: ConcretePhotosBackupUpdateTelemetryDataFactory(repository: valuesRepository, userInfoFactory: userInfoFactory))
    }
}
