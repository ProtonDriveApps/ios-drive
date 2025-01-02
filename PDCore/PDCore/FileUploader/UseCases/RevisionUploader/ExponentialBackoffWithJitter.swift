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

import Foundation

public final class ExponentialBackoffWithJitter {

    public static func getDelay(attempt n: Int) -> TimeInterval {
        let maxDelay = 600000 // 10 minutes in milliseconds
        if n == 0 { return 0 } // No delay for the first attempt
        let delay = Int(pow(2.0, Double(n - 1))) * 1000
        let jitter = Int.random(in: 0...1000)
        return TimeInterval(min(delay + jitter, maxDelay)) / 1000
    }

}
