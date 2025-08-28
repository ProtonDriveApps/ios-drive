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

struct Month: Equatable {
    let month: Int
    let year: Int
}

protocol MonthResource {
    func getMonth(from date: Date) -> Month
}

final class PlatformMonthResource: MonthResource {
    private static let calendar = Calendar.current

    func getMonth(from date: Date) -> Month {
        let components = PlatformMonthResource.calendar.dateComponents([.month, .year], from: date)
        return Month(month: components.month ?? 0, year: components.year ?? 0)
    }
}
