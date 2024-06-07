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
    func makeData(with duration: Double) -> TelemetryData
}

final class ConcretePhotosBackupBackgroundUpdateTelemetryDataFactory: PhotosBackupBackgroundUpdateTelemetryDataFactory {
    private let userInfoFactory: PhotosTelemetryUserInfoFactory
    private let dateResource: DateResource
    private let storage: PhotosTelemetryStorage
    private let hourFormatter: HourValueFormatter

    init(userInfoFactory: PhotosTelemetryUserInfoFactory, dateResource: DateResource, storage: PhotosTelemetryStorage, hourFormatter: HourValueFormatter) {
        self.userInfoFactory = userInfoFactory
        self.dateResource = dateResource
        self.storage = storage
        self.hourFormatter = hourFormatter
    }

    func makeData(with duration: Double) -> TelemetryData {
        return TelemetryData(
            group: .photos,
            event: .backupBackgroundUpdate,
            values: makeValues(duration: duration),
            dimensions: makeDimensions()
        )
    }

    private func makeValues(duration: Double) -> [String: Double] {
        return [
            "hour": getHour(),
            "duration_seconds": duration,
        ]
    }

    private func getHour() -> Double {
        let date = dateResource.getDate()
        let hour = hourFormatter.getHour(from: date)
        return Double(hour)
    }

    private func makeDimensions() -> [String: String] {
        var dimensions = userInfoFactory.makeDimensions()
        dimensions["is_initial_backup"] = storage.isInitialBackup ? "yes" : "no"
        return dimensions
    }
}
