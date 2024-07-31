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

final class PhotosTelemetryContainer {
    struct Dependencies {
        let tower: Tower
        let settingsSuite: SettingsStorageSuite
        let settingsController: PhotoBackupSettingsController
        let stateController: PhotosBackupStateController
        let storage: PhotosTelemetryStorage
        let loadController: PhotoLibraryLoadController
        let uploadRepository: DurationMeasurementRepository
        let scanningRepository: DurationMeasurementRepository
        let duplicatesRepository: DurationMeasurementRepository
        let throttlingRepository: DurationMeasurementRepository
        let computationalAvailabilityController: ComputationalAvailabilityController
        let uploadDoneNotifier: PhotoUploadDoneNotifier
        let processingTaskController: BackgroundTaskStateController
        let backgroundUploadMeasurementsRepository: BackgroundUploadMeasurementsRepositoryProtocol
        let backgroundTaskResultStateRepository: BackgroundTaskResultStateRepositoryProtocol
        let failedPhotosResource: DeletedPhotosIdentifierStoreResource
        let networkController: PhotoBackupNetworkControllerProtocol
    }

    private let dependencies: Dependencies
    private let telemetryController: TelemetryController
    private let settingController: PhotosTelemetrySettingController
    private let stopController: PhotosBackupStopTelemetryController
    private let updateController: PhotosBackupUpdateTelemetryController
    private let uploadDoneController: PhotoUploadDoneTelemetryController
    private let backgroundUpdateController: PhotosBackupBackgroundUpdateTelemetryController
    private let backgroundStartController: PhotosBackupBackgroundStartTelemetryController

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        telemetryController = TelemetryFactory().makeController(tower: dependencies.tower)
        let factory = PhotosTelemetryFactory()
        settingController = factory.makeSettingController(tower: dependencies.tower, settingsController: dependencies.settingsController, telemetryController: telemetryController)
        stopController = factory.makeStopController(tower: dependencies.tower, stateController: dependencies.stateController, telemetryController: telemetryController, storage: dependencies.storage, loadController: dependencies.loadController, failedPhotosResource: dependencies.failedPhotosResource)
        let updateFactory = PhotosBackupUpdateTelemetryFactory()
        updateController = updateFactory.makeController(telemetryController: telemetryController, stateController: dependencies.stateController, storage: dependencies.storage, userInfoResource: dependencies.tower.sessionVault, uploadRepository: dependencies.uploadRepository, scanningRepository: dependencies.scanningRepository, duplicatesRepository: dependencies.duplicatesRepository, throttlingRepository: dependencies.throttlingRepository, networkController: dependencies.networkController)
        let uploadDoneFactory = PhotoUploadDoneTelemetryFactory()
        uploadDoneController = uploadDoneFactory.makeController(telemetryController: telemetryController, computationalAvailabilityController: dependencies.computationalAvailabilityController, storage: dependencies.storage, userInfoResource: dependencies.tower.sessionVault, notifier: dependencies.uploadDoneNotifier, networkController: dependencies.networkController)
        let backgroundUpdateFactory = PhotosBackupBackgroundUpdateTelemetryFactory()
        let backgroundUploadStorage = backgroundUpdateFactory.makeBackgroundStorage(suite: dependencies.settingsSuite)
        backgroundUpdateController = backgroundUpdateFactory.makeController(telemetryController: telemetryController, taskController: dependencies.processingTaskController, backupStorage: dependencies.storage, backgroundUploadStorage: backgroundUploadStorage, userInfoResource: dependencies.tower.sessionVault, uploadMeasurementsRepository: dependencies.backgroundUploadMeasurementsRepository, networkController: dependencies.networkController)
        let backgroundStartFactory = PhotosBackupBackgroundStartTelemetryFactory()
        backgroundStartController = backgroundStartFactory.makeController(telemetryController: telemetryController, availabilityController: dependencies.computationalAvailabilityController, backupStorage: dependencies.storage, userInfoResource: dependencies.tower.sessionVault, backgroundUploadStorage: backgroundUploadStorage, networkController: dependencies.networkController)

    }
}
