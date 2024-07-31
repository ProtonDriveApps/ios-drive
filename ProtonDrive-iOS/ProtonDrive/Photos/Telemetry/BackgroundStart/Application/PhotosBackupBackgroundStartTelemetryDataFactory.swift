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

import Foundation
import PDCore

protocol PhotosBackupBackgroundStartTelemetryDataFactoryProtocol {
    func makeData() -> TelemetryData
}

final class PhotosBackupBackgroundStartTelemetryDataFactory: PhotosBackupBackgroundStartTelemetryDataFactoryProtocol {
    private let userInfoFactory: PhotosTelemetryUserInfoFactory
    private let dateResource: DateResource
    private let backupStorage: PhotosTelemetryStorage
    private let backgroundUploadStorage: PhotosBackupBackgroundTelemetryStorageProtocol

    init(userInfoFactory: PhotosTelemetryUserInfoFactory, dateResource: DateResource, backupStorage: PhotosTelemetryStorage, backgroundUploadStorage: PhotosBackupBackgroundTelemetryStorageProtocol) {
        self.userInfoFactory = userInfoFactory
        self.dateResource = dateResource
        self.backupStorage = backupStorage
        self.backgroundUploadStorage = backgroundUploadStorage
    }

    func makeData() -> TelemetryData {
        return TelemetryData(
            group: .photos,
            event: .backupBackgroundStart,
            values: makeValues(),
            dimensions: makeDimensions()
        )
    }

    private func makeValues() -> [String: Double] {
        guard let lastActivityDate = backgroundUploadStorage.lastActivityDate else {
            return [:]
        }

        let currentDate = dateResource.getDate()
        let differenceInSeconds = currentDate.timeIntervalSinceReferenceDate - lastActivityDate.timeIntervalSinceReferenceDate
        return ["seconds_since_last_activity": differenceInSeconds]
    }

    private func makeDimensions() -> [String: String] {
        var dimensions = userInfoFactory.makeDimensions()
        dimensions["is_initial_backup"] = backupStorage.isInitialBackup ? "yes" : "no"
        let isFirstBackgroundOperation = backgroundUploadStorage.isFirstBackgroundOperation ?? true
        dimensions["is_first_operation"] = isFirstBackgroundOperation ? "yes" : "no"
        dimensions["previous_result_state"] = getResultState()
        return dimensions
    }

    private func getResultState() -> String {
        guard let resultState = backgroundUploadStorage.resultState else {
            // First run of the app will not have previously stored state
            let hasStartedBackgroundOperation = backgroundUploadStorage.hasStartedBackgroundOperation ?? false
            // With this, we can differentiate between exception state occuring and no previous run
            return hasStartedBackgroundOperation ? "unknown" : "none"
        }

        switch resultState {
        case .completed:
            return "completed"
        case .expired:
            return "expired"
        case .foreground:
            return "foreground"
        }
    }
}
