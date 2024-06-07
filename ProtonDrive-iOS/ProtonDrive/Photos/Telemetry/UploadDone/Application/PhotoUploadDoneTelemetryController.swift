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

protocol PhotoUploadDoneTelemetryController {}

final class ConcretePhotoUploadDoneTelemetryController: PhotoUploadDoneTelemetryController {
    private let telemetryController: TelemetryController
    private let computationAvailabilityController: ComputationalAvailabilityController
    private let notifier: PhotoUploadDoneNotifier
    private let storage: PhotosTelemetryStorage
    private let dataFactory: PhotoUploadDoneTelemetryDataFactory
    private var isBackgroundTask = false
    private var cancellables = Set<AnyCancellable>()

    init(telemetryController: TelemetryController, computationAvailabilityController: ComputationalAvailabilityController, notifier: PhotoUploadDoneNotifier, storage: PhotosTelemetryStorage, userInfoResource: UserInfoResource, dataFactory: PhotoUploadDoneTelemetryDataFactory) {
        self.telemetryController = telemetryController
        self.computationAvailabilityController = computationAvailabilityController
        self.notifier = notifier
        self.storage = storage
        self.dataFactory = dataFactory
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        notifier.data
            .sink { [weak self] data in
                self?.handleUpdate(data)
            }
            .store(in: &cancellables)

        computationAvailabilityController.availability
            .map { availability in
                switch availability {
                case .processingTask:
                    return true
                case .suspended, .foreground, .extensionTask:
                    return false
                }
            }
            .sink { [weak self] isBackgroundTask in
                self?.isBackgroundTask = isBackgroundTask
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ data: PhotoUploadDoneData) {
        let data = PhotoUploadTelemetryData(
            isSuccess: data.isSuccess,
            kilobytes: data.kilobytes,
            duration: data.duration,
            isInitialBackup: storage.isInitialBackup,
            isBackgroundTask: isBackgroundTask
        )
        let telemetryData = dataFactory.makeData(with: data)
        telemetryController.send(data: telemetryData)
    }
}
