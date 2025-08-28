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

import PMEventsManager

/// There's just one volume (main) which should be polled every 90 seconds.
/// No restrictions, this class keeps same functionality with the non-volume-migrated target.
final class SingleVolumeEventLoopsTimingController: EventLoopsTimingController {

    var interval: Double

    init(interval: Double) {
        self.interval = interval
    }

    func getInterval() -> Double {
        return interval
    }

    func getReadyLoops(possible: [LoopID]) -> [LoopID] {
        // always execute all possible loops
        return possible
    }

    func setExecutedLoops(loopIds: [LoopID]) {
        // no-op
    }

    func updateHistoryForForcePolling(volumeIDs: [String]) {
        
    }
}
