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

protocol PhotosBackupBackgroundUpdateTelemetryDataFactory {
    func makeData(with data: BackupBackgroundUpdateTelemetryData) -> TelemetryData
}

struct BackupBackgroundUpdateTelemetryData {
    let duration: Double
    let uploadMeasurements: BackgroundUploadMeasurements
}

final class ConcretePhotosBackupBackgroundUpdateTelemetryDataFactory: PhotosBackupBackgroundUpdateTelemetryDataFactory {
    private let userInfoFactory: PhotosTelemetryUserInfoFactory
    private let dateResource: DateResource
    private let storage: PhotosTelemetryStorage
    private let hourFormatter: HourValueFormatter
    private let connectionFactory: PhotosTelemetryConnectionFactoryProtocol

    init(userInfoFactory: PhotosTelemetryUserInfoFactory, dateResource: DateResource, storage: PhotosTelemetryStorage, hourFormatter: HourValueFormatter, connectionFactory: PhotosTelemetryConnectionFactoryProtocol) {
        self.userInfoFactory = userInfoFactory
        self.dateResource = dateResource
        self.storage = storage
        self.hourFormatter = hourFormatter
        self.connectionFactory = connectionFactory
    }

    func makeData(with data: BackupBackgroundUpdateTelemetryData) -> TelemetryData {
        return TelemetryData(
            group: .photos,
            event: .backupBackgroundUpdate,
            values: makeValues(with: data),
            dimensions: makeDimensions(with: data)
        )
    }

    private func makeValues(with data: BackupBackgroundUpdateTelemetryData) -> [String: Double] {
        return [
            "hour": getHour(),
            "duration_seconds": data.duration,
            "files_started": Double(data.uploadMeasurements.startedFilesCount),
            "files_finished": Double(data.uploadMeasurements.succeededFilesCount),
            "files_failed": Double(data.uploadMeasurements.failedFilesCount),
            "blocks_uploaded": Double(data.uploadMeasurements.succeededBlocksCount)
        ]
    }

    private func getHour() -> Double {
        let date = dateResource.getDate()
        let hour = hourFormatter.getHour(from: date)
        return Double(hour)
    }

    private func makeDimensions(with data: BackupBackgroundUpdateTelemetryData) -> [String: String] {
        var dimensions = userInfoFactory.makeDimensions()
        dimensions["is_initial_backup"] = storage.isInitialBackup ? "yes" : "no"
        dimensions["result_state"] = data.uploadMeasurements.state.map(makeState)
        dimensions.merge(connectionFactory.makeDimensions(), uniquingKeysWith: { current, _ in current })
        return dimensions
    }

    private func makeState(from state: BackgroundTaskResultState) -> String {
        switch state {
        case .expired:
            return "expired"
        case .completed:
            return "completed"
        case .foreground:
            return "foreground"
        }
    }
}
