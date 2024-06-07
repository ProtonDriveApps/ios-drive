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
import Foundation
import PDCore

protocol PhotosBackupDurationController {
    func stop()
}

final class SavingPhotosBackupDurationController: PhotosBackupDurationController {
    private let backupStateController: PhotosBackupStateController
    private let dateResource: DateResource
    private let storage: PhotosTelemetryStorage
    private var cancellables = Set<AnyCancellable>()
    private var startDate: Date?

    init(backupStateController: PhotosBackupStateController, dateResource: DateResource, storage: PhotosTelemetryStorage) {
        self.backupStateController = backupStateController
        self.dateResource = dateResource
        self.storage = storage
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        backupStateController.state
            .map { [weak self] state in
                self?.isInProgress(state) ?? false
            }
            .sink { [weak self] isInProgress in
                self?.handleUpdate(isInProgress)
            }
            .store(in: &cancellables)
    }

    private func isInProgress(_ state: PhotosBackupState) -> Bool {
        switch state {
        case .inProgress:
            return true
        default:
            return false
        }
    }

    private func handleUpdate(_ isInProgress: Bool) {
        if isInProgress {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        handleUpdate()
        startDate = dateResource.getDate()
    }

    func stop() {
        handleUpdate()
        startDate = nil
    }

    private func handleUpdate() {
        guard let startDate else { return }
        let date = dateResource.getDate()
        let duration = date.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        storage.backupDuration += duration
    }
}
