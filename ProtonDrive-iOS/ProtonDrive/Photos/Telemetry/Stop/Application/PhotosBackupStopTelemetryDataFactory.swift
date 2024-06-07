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

struct PhotosBackupStopTelemetryData {
    let state: PhotosBackupState
    let localItemsCount: Int?
}

enum PhotosBackupStopTelemetryDataFactoryError: Error {
    case invalidEvent
}

protocol PhotosBackupStopTelemetryDataFactory {
    func makeData(with data: PhotosBackupStopTelemetryData) throws -> TelemetryData
}

final class ConcretePhotosBackupStopTelemetryDataFactory: PhotosBackupStopTelemetryDataFactory {
    private let storage: PhotosTelemetryStorage
    private let userInfoFactory: PhotosTelemetryUserInfoFactory

    init(storage: PhotosTelemetryStorage, userInfoFactory: PhotosTelemetryUserInfoFactory) {
        self.storage = storage
        self.userInfoFactory = userInfoFactory
    }

    func makeData(with data: PhotosBackupStopTelemetryData) throws -> TelemetryData {
        TelemetryData(
            group: .photos,
            event: .backupStopped,
            values: makeValues(with: data),
            dimensions: try makeDimensions(from: data)
        )
    }

    private func makeValues(with data: PhotosBackupStopTelemetryData) -> [String: Double] {
        var values = [
            "duration_seconds": storage.backupDuration,
            "files_uploaded": storage.uploadedFilesCount,
            "bytes_uploaded": storage.uploadedBytesCount,
        ]
        values["number_of_local_items"] = data.localItemsCount.map { Double($0) }
        return values
    }

    private func makeDimensions(from data: PhotosBackupStopTelemetryData) throws -> [String: String] {
        var dimensions = userInfoFactory.makeDimensions()
        dimensions["is_initial_backup"] = storage.isInitialBackup ? "yes" : "no"
        dimensions["reason"] = try makeReason(from: data)
        dimensions["reason_group"] = try makeReasonGroup(from: data)
        return dimensions
    }

    private func makeReason(from data: PhotosBackupStopTelemetryData) throws -> String {
        switch data.state {
        case .complete:
            return "completed"
        case .completeWithFailures:
            return "failed items"
        case .disabled:
            return "disabled by user"
        case .restrictedPermissions:
            return "permissions"
        case .networkConstrained:
            return "no connection"
        case .storageConstrained:
            return "out of local storage"
        case .featureFlag:
            return "feature flags"
        case .quotaConstrained:
            return "out of drive storage"
        case .applicationStateConstrained:
            return "background mode expired"
        case .empty, .inProgress, .libraryLoading:
            throw PhotosBackupStopTelemetryDataFactoryError.invalidEvent
        }
    }

    private func makeReasonGroup(from data: PhotosBackupStopTelemetryData) throws -> String {
        switch data.state {
        case .complete:
            return "completed"
        case .completeWithFailures:
            return "failed"
        case .networkConstrained, .disabled, .applicationStateConstrained:
            return "paused"
        case .restrictedPermissions, .storageConstrained, .quotaConstrained, .featureFlag:
            return "failed"
        case .empty, .inProgress, .libraryLoading:
            throw PhotosBackupStopTelemetryDataFactoryError.invalidEvent
        }
    }
}
