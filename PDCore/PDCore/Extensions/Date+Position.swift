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

extension Date {

    struct Past {
        static func sixHours(from date: Date = Date()) -> Date {
            date.addingTimeInterval(-TimeInterval(6 * 3600))
        }

        static func twentyFourHours(from date: Date = Date()) -> Date {
            date.addingTimeInterval(-TimeInterval(24 * 3600))
        }

        static func threeDays(from date: Date = Date()) -> Date {
            date.addingTimeInterval(-TimeInterval(3 * 24 * 3600))
        }
    }
}
