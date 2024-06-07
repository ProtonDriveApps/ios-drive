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

protocol PhotosBackupStopTelemetryController {}

final class ConcretePhotosBackupStopTelemetryController: PhotosBackupStopTelemetryController {
    private let stateController: PhotosBackupStateController
    private let telemetryController: TelemetryController
    private let durationController: PhotosBackupDurationController
    private let dataFactory: PhotosBackupStopTelemetryDataFactory
    private let storage: PhotosTelemetryStorage
    private let loadController: PhotoLibraryLoadController
    private var isBackupStarted = false
    private var cancellables = Set<AnyCancellable>()

    init(stateController: PhotosBackupStateController, telemetryController: TelemetryController, durationController: PhotosBackupDurationController, dataFactory: PhotosBackupStopTelemetryDataFactory, storage: PhotosTelemetryStorage, loadController: PhotoLibraryLoadController) {
        self.stateController = stateController
        self.telemetryController = telemetryController
        self.durationController = durationController
        self.dataFactory = dataFactory
        self.storage = storage
        self.loadController = loadController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        stateController.state
            .map { [weak self] state in
                let localItemsCount = self?.loadController.getInitialCount()
                return PhotosBackupStopTelemetryData(state: state, localItemsCount: localItemsCount)
            }
            .sink { [weak self] data in
                self?.handleUpdate(data: data)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(data: PhotosBackupStopTelemetryData) {
        if case .inProgress = data.state {
            isBackupStarted = true
        }
        guard isValidState(state: data.state) else {
            return
        }

        durationController.stop()
        sendData(with: data)
        resetStorageIfNecessary(data: data)
    }

    private func isValidState(state: PhotosBackupState) -> Bool {
        return isBackupStarted && isRelevantState(state: state)
    }

    private func sendData(with data: PhotosBackupStopTelemetryData) {
        if let telemetryData = try? dataFactory.makeData(with: data) {
            telemetryController.send(data: telemetryData)
        }
    }

    private func resetStorageIfNecessary(data: PhotosBackupStopTelemetryData) {
        if data.state == .complete {
            storage.reset()
        }
    }

    private func isRelevantState(state: PhotosBackupState) -> Bool {
        switch state {
        case .empty, .inProgress, .libraryLoading:
            return false
        case .complete, .completeWithFailures, .disabled, .restrictedPermissions, .networkConstrained, .storageConstrained, .quotaConstrained, .featureFlag, .applicationStateConstrained:
            return true
        }
    }
}
