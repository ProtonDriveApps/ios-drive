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

public protocol PhotoUploadMeasurementsStorage {
    subscript(index: String) -> Double? { get set }
}

final class UserDefaultsPhotoUploadMeasurementsStorage: PhotoUploadMeasurementsStorage {
    private typealias Measurements = [String: Double]
    private let queue = DispatchQueue(label: "PhotoUploadMeasurementsStorage", qos: .userInteractive, attributes: .concurrent)
    @SettingsStorage("photo-upload-measurements") private var onDiskStorage: Measurements?
    private lazy var inMemoryStorage: Measurements = loadFromDisk()

    subscript(index: String) -> Double? {
        get {
            return queue.sync {
                return inMemoryStorage[index]
            }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.inMemoryStorage[index] = newValue
                self?.onDiskStorage = self?.inMemoryStorage
            }
        }
    }

    private func loadFromDisk() -> Measurements {
        return onDiskStorage ?? [:]
    }
}
