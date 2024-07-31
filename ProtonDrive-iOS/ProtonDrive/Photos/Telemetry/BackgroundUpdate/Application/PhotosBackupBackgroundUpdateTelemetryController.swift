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

import Combine
import PDCore

protocol PhotosBackupBackgroundUpdateTelemetryController {}

final class ConcretePhotosBackupBackgroundUpdateTelemetryController: PhotosBackupBackgroundUpdateTelemetryController {
    private let telemetryController: TelemetryController
    private let taskController: BackgroundTaskStateController
    private let durationMeasurementRepository: DurationMeasurementRepository
    private let uploadMeasurementsRepository: BackgroundUploadMeasurementsRepositoryProtocol
    private let dataFactory: PhotosBackupBackgroundUpdateTelemetryDataFactory
    private let storage: PhotosBackupBackgroundTelemetryStorageProtocol
    private var isMeasuring = false
    private var cancellables = Set<AnyCancellable>()

    init(telemetryController: TelemetryController, taskController: BackgroundTaskStateController, durationMeasurementRepository: DurationMeasurementRepository, uploadMeasurementsRepository: BackgroundUploadMeasurementsRepositoryProtocol, dataFactory: PhotosBackupBackgroundUpdateTelemetryDataFactory, storage: PhotosBackupBackgroundTelemetryStorageProtocol) {
        self.telemetryController = telemetryController
        self.taskController = taskController
        self.durationMeasurementRepository = durationMeasurementRepository
        self.uploadMeasurementsRepository = uploadMeasurementsRepository
        self.dataFactory = dataFactory
        self.storage = storage
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        taskController.isRunning
            .removeDuplicates()
            .sink { [weak self] isRunning in
                self?.handleUpdate(isRunning)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ isTaskRunning: Bool) {
        // Only handle update if state changes. (Also filters initial `false` state if published)
        guard isTaskRunning != isMeasuring else {
            return
        }

        if isTaskRunning {
            durationMeasurementRepository.start()
            uploadMeasurementsRepository.reset() // Reset measurements since they can contain entries from FG backup
            Log.debug("Handle background task update: started measurement", domain: .telemetry)
        } else if !isTaskRunning {
            durationMeasurementRepository.stop()
            processMeasurements()
            durationMeasurementRepository.reset()
            Log.debug("Handle background task update: stopped measurement", domain: .telemetry)
        }
        isMeasuring = isTaskRunning
    }

    private func processMeasurements() {
        let measurements = uploadMeasurementsRepository.getMeasurements()
        let data = BackupBackgroundUpdateTelemetryData(
            duration: durationMeasurementRepository.get(),
            uploadMeasurements: measurements
        )
        let telemetryData = dataFactory.makeData(with: data)
        telemetryController.send(data: telemetryData)
        storage.resultState = measurements.state
    }
}
