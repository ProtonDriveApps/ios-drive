// Copyright (c) 2025 Proton AG
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

struct EventLoopTimingConstants {
    private var isDebug: Bool {
        #if DEBUG
        return Constants.isUnitTest ? false : true
        #else
        return false
        #endif
    }

    /// Timer fire interval
    var eventLoopRefillInterval: TimeInterval {
        isDebug ? 10.seconds : 30.seconds
    }

    /// Time interval between 2 event loop call
    func ownedVolumeThreshold(isBackground: Bool) -> Double {
        var interval = isBackground ? 30.0.minutes : 30.0.seconds
        if isDebug {
            interval /= 3
        }
        return interval
    }

    /// Time interval between 2 event loop call
    func sharedVolumeThreshold(isBackground: Bool, isActive: Bool) -> Double {
        var interval: Double
        if isBackground {
            interval = 24.0.hours
        } else if isActive {
            interval = 30.0.seconds
        } else {
            interval = 10.0.minutes
        }

        if isDebug {
            interval /= 3
        }

        return interval
    }
}
