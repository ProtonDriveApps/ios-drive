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

protocol MonthAndYearFormatter {
    func formatMonth(date: Date) -> String
    func formatMonthAndYear(date: Date) -> String
}

final class PlatformMonthAndYearFormatter: MonthAndYearFormatter {
    private static let monthFomatter = makeFormatter(format: "MMMM")
    private static let monthAndYearFormatter = makeFormatter(format: "MMMM yyyy")

    private static func makeFormatter(format: String) -> DateFormatter {
        let dateFormatter = DateFormatter()
        // Until we translate other texts on the screens, this needs to be english
        dateFormatter.locale = Locale(identifier: "en")
        dateFormatter.dateFormat = format
        return dateFormatter
    }

    func formatMonth(date: Date) -> String {
        PlatformMonthAndYearFormatter.monthFomatter.string(from: date)
    }

    func formatMonthAndYear(date: Date) -> String {
        PlatformMonthAndYearFormatter.monthAndYearFormatter.string(from: date)
    }
}
