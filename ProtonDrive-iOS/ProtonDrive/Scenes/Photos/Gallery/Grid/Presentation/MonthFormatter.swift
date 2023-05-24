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

protocol MonthFormatter {
    func formatMonth(from date: Date) -> String
}

final class LocalizedMonthFormatter: MonthFormatter {
    private let dateResource: DateResource
    private let dateFormatter: MonthAndYearFormatter
    private let monthResource: MonthResource

    init(dateResource: DateResource, dateFormatter: MonthAndYearFormatter, monthResource: MonthResource) {
        self.dateResource = dateResource
        self.dateFormatter = dateFormatter
        self.monthResource = monthResource
    }

    func formatMonth(from date: Date) -> String {
        let currentMonth = monthResource.getMonth(from: dateResource.getCurrentDate())
        let month = monthResource.getMonth(from: date)
        if currentMonth == month {
            return "This month"
        } else if currentMonth.year == month.year {
            return dateFormatter.formatMonth(date: date)
        } else {
            return dateFormatter.formatMonthAndYear(date: date)
        }
    }
}
