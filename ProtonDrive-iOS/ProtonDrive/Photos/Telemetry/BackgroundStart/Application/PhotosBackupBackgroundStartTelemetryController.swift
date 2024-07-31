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
import Foundation
import PDCore

protocol PhotosBackupBackgroundStartTelemetryControllerProtocol {}

final class PhotosBackupBackgroundStartTelemetryController: PhotosBackupBackgroundStartTelemetryControllerProtocol {
    private let telemetryController: TelemetryController
    private let availabilityController: ComputationalAvailabilityController
    private let dataFactory: PhotosBackupBackgroundStartTelemetryDataFactoryProtocol
    private let storage: PhotosBackupBackgroundTelemetryStorageProtocol
    private let dateResource: DateResource
    private var cancellables = Set<AnyCancellable>()

    init(telemetryController: TelemetryController, availabilityController: ComputationalAvailabilityController, dataFactory: PhotosBackupBackgroundStartTelemetryDataFactoryProtocol, storage: PhotosBackupBackgroundTelemetryStorageProtocol, dateResource: DateResource) {
        self.telemetryController = telemetryController
        self.availabilityController = availabilityController
        self.dataFactory = dataFactory
        self.storage = storage
        self.dateResource = dateResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        availabilityController.availability
            .removeDuplicates()
            .sink { [weak self] availability in
                self?.handleUpdate(with: availability)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(with availability: ComputationalAvailability) {
        switch availability {
        case .foreground:
            handleForegroundStart()
        case .suspended, .extensionTask:
            break
        case .processingTask:
            handleProcessingStart()
        }
    }

    private func handleProcessingStart() {
        Log.debug("\(Self.self): handle background task start: send events and update storage.", domain: .telemetry)
        let telemetryData = dataFactory.makeData()
        telemetryController.send(data: telemetryData)
        // Store current run related data, which will be used in the subsequent runs
        storage.lastActivityDate = dateResource.getDate()
        storage.isFirstBackgroundOperation = false
        storage.hasStartedBackgroundOperation = true
    }

    private func handleForegroundStart() {
        Log.debug("\(Self.self): handle availability change.", domain: .telemetry)
        // Will reset the background operation related data
        // The app is active now, so the next BG session will be first
        storage.lastActivityDate = dateResource.getDate()
        storage.isFirstBackgroundOperation = true
    }
}
