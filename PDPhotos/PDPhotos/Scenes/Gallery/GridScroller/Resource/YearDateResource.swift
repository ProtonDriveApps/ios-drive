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

protocol YearDateResource {
    func isSameYear(lhs: Date, rhs: Date) -> Bool
    func getDistance(lhs: Date, rhs: Date) -> Int
}

final class PlatformYearDateResource: YearDateResource {
    private static let calendar = Calendar.current

    func isSameYear(lhs: Date, rhs: Date) -> Bool {
        let lhsYear = PlatformYearDateResource.calendar.dateComponents([.year], from: lhs)
        let rhsYear = PlatformYearDateResource.calendar.dateComponents([.year], from: rhs)
        return lhsYear.year == rhsYear.year
    }

    func getDistance(lhs: Date, rhs: Date) -> Int {
        let lhsYear = PlatformYearDateResource.calendar.dateComponents([.year], from: lhs).year ?? 0
        let rhsYear = PlatformYearDateResource.calendar.dateComponents([.year], from: rhs).year ?? 0
        return abs(lhsYear - rhsYear)
    }
}
