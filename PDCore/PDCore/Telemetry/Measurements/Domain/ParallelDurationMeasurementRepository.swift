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

/// Multiple starts & stops can be invoked. The measurement shouldn't be affected by degree of parallelism, it should signify how long a given module was working.
/// Every `start` should correspond to a single `stop` invocation.
final class ParallelDurationMeasurementRepository: DurationMeasurementRepository {
    private let dateResource: DateResource
    private var startTimeInterval: TimeInterval = 0
    private var counter = 0
    private var duration: TimeInterval = 0

    init(dateResource: DateResource) {
        self.dateResource = dateResource
    }

    func start() {
        if counter == 0 {
            startTimeInterval = getCurrentInterval()
        }
        counter += 1
    }

    func stop() {
        guard counter > 0 else {
            return
        }
        counter -= 1
        if counter == 0 {
            duration += getCurrentInterval() - startTimeInterval
        }
    }

    func get() -> Double {
        if counter > 0 {
            let intervalSinceLastStart = getCurrentInterval() - startTimeInterval
            return duration + intervalSinceLastStart
        }
        return duration
    }

    func reset() {
        duration = 0
        if counter > 0 {
            startTimeInterval = getCurrentInterval()
        }
    }

    private func getCurrentInterval() -> TimeInterval {
        return dateResource.getDate().timeIntervalSinceReferenceDate
    }
}
