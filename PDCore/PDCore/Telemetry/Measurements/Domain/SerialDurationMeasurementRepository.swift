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

/// Serial tracking of duration, it's not possible to start tracking without previously stopping.
final class SerialDurationMeasurementRepository: DurationMeasurementRepository {
    private let dateResource: DateResource
    private var startTimeInterval: TimeInterval?
    private var duration: TimeInterval = 0

    init(dateResource: DateResource) {
        self.dateResource = dateResource
    }

    func start() {
        guard startTimeInterval == nil else { return }
        startTimeInterval = getCurrentInterval()
    }

    func stop() {
        guard let startTimeInterval else { return }
        self.startTimeInterval = nil
        duration += getCurrentInterval() - startTimeInterval
    }

    func get() -> Double {
        return duration
    }

    func reset() {
        startTimeInterval = nil
        duration = 0
    }

    private func getCurrentInterval() -> TimeInterval {
        return dateResource.getDate().timeIntervalSinceReferenceDate
    }
}
