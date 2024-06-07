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

struct PhotosBackupUpdateValues {
    let isInitialBackup: Bool
    let filesCount: Double
    let kilobytesCount: Double
    let duration: Double
    let uploadDuration: Double
    let scanningDuration: Double
    let duplicatesDuration: Double
    let throttlingDuration: Double
}

protocol PhotosBackupUpdateValuesRepository {
    func reset()
    func get() -> PhotosBackupUpdateValues
}

final class ConcretePhotosBackupUpdateValuesRepository: PhotosBackupUpdateValuesRepository {
    private let uploadRepository: DurationMeasurementRepository
    private let scanningRepository: DurationMeasurementRepository
    private let duplicatesRepository: DurationMeasurementRepository
    private let throttlingRepository: DurationMeasurementRepository
    private let storage: PhotosTelemetryStorage
    private var previousFilesCount: Double = 0
    private var previousBytesCount: Double = 0
    private let duration: Double

    init(uploadRepository: DurationMeasurementRepository, scanningRepository: DurationMeasurementRepository, duplicatesRepository: DurationMeasurementRepository, throttlingRepository: DurationMeasurementRepository, storage: PhotosTelemetryStorage, duration: Double) {
        self.uploadRepository = uploadRepository
        self.scanningRepository = scanningRepository
        self.duplicatesRepository = duplicatesRepository
        self.throttlingRepository = throttlingRepository
        self.storage = storage
        self.duration = duration
        markCurrentStorageValues()
    }

    func get() -> PhotosBackupUpdateValues {
        PhotosBackupUpdateValues(
            isInitialBackup: storage.isInitialBackup,
            filesCount: storage.uploadedFilesCount - previousFilesCount,
            kilobytesCount: round((storage.uploadedBytesCount - previousBytesCount) / 1024),
            duration: duration,
            uploadDuration: uploadRepository.get(),
            scanningDuration: scanningRepository.get(),
            duplicatesDuration: duplicatesRepository.get(),
            throttlingDuration: throttlingRepository.get()
        )
    }

    func reset() {
        [uploadRepository, scanningRepository, duplicatesRepository, throttlingRepository].forEach {
            $0.reset()
        }
        markCurrentStorageValues()
    }

    private func markCurrentStorageValues() {
        previousFilesCount = storage.uploadedFilesCount
        previousBytesCount = storage.uploadedBytesCount
    }
}
