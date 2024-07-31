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

import PDCore

protocol PhotosBackupUpdateTelemetryDataFactory {
    func makeData() -> TelemetryData
}

final class ConcretePhotosBackupUpdateTelemetryDataFactory: PhotosBackupUpdateTelemetryDataFactory {
    private let repository: PhotosBackupUpdateValuesRepository
    private let userInfoFactory: PhotosTelemetryUserInfoFactory
    private let connectionFactory: PhotosTelemetryConnectionFactoryProtocol

    init(repository: PhotosBackupUpdateValuesRepository, userInfoFactory: PhotosTelemetryUserInfoFactory, connectionFactory: PhotosTelemetryConnectionFactoryProtocol) {
        self.repository = repository
        self.userInfoFactory = userInfoFactory
        self.connectionFactory = connectionFactory
    }

    func makeData() -> TelemetryData {
        let values = repository.get()
        return TelemetryData(
            group: .photos,
            event: .backupUpdate,
            values: makeValues(from: values),
            dimensions: makeDimensions(from: values)
        )
    }

    private func makeValues(from values: PhotosBackupUpdateValues) -> [String: Double] {
        return [
            "kilobytes_uploaded": values.kilobytesCount,
            "files_uploaded": values.filesCount,
            "duration_seconds": values.duration,
            "upload_seconds": values.uploadDuration,
            "scanning_gallery_seconds": values.scanningDuration,
            "duplicates_processing_seconds": values.duplicatesDuration,
            "thermal_throttling_seconds": values.throttlingDuration
        ]
    }

    private func makeDimensions(from values: PhotosBackupUpdateValues) -> [String: String] {
        var dimensions = userInfoFactory.makeDimensions()
        dimensions["is_initial_backup"] = values.isInitialBackup ? "yes" : "no"
        dimensions.merge(connectionFactory.makeDimensions(), uniquingKeysWith: { current, _ in current })
        return dimensions
    }
}
