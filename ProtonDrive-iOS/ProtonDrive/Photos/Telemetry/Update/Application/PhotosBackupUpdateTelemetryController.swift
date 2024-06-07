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

protocol PhotosBackupUpdateTelemetryController {}

final class ConcretePhotosBackupUpdateTelemetryController: PhotosBackupUpdateTelemetryController {
    private let telemetryController: TelemetryController
    private let stateController: PhotosBackupStateController
    private let valuesRepository: PhotosBackupUpdateValuesRepository
    private let timerResource: PausableTimerResource
    private let dataFactory: PhotosBackupUpdateTelemetryDataFactory
    private var cancellables = Set<AnyCancellable>()

    init(telemetryController: TelemetryController, stateController: PhotosBackupStateController, valuesRepository: PhotosBackupUpdateValuesRepository, timerResource: PausableTimerResource, dataFactory: PhotosBackupUpdateTelemetryDataFactory) {
        self.telemetryController = telemetryController
        self.stateController = stateController
        self.valuesRepository = valuesRepository
        self.timerResource = timerResource
        self.dataFactory = dataFactory
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        stateController.state
            .map { state in
                // The heartbeat timer is only active if backup is in one of the active states.
                switch state {
                case .inProgress, .libraryLoading:
                    return true
                case .applicationStateConstrained, .complete, .completeWithFailures, .disabled, .empty, .featureFlag, .networkConstrained, .quotaConstrained, .restrictedPermissions, .storageConstrained:
                    return false
                }
            }
            .removeDuplicates()
            .sink { [weak self] isRunning in
                self?.handleRunning(isRunning)
            }
            .store(in: &cancellables)

        timerResource.updatePublisher
            .sink { [weak self] in
                self?.handleUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleRunning(_ isRunning: Bool) {
        if isRunning {
            timerResource.resume()
        } else {
            timerResource.pause()
        }
    }

    private func handleUpdate() {
        let data = dataFactory.makeData()
        telemetryController.send(data: data)
        valuesRepository.reset()
    }
}
