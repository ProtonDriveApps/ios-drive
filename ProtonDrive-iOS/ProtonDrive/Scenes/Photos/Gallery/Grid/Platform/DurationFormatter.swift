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

protocol DurationFormatter {
    func formatDuration(from interval: UInt) -> String
}

final class LocalizedDurationFormatter: DurationFormatter {
    private static let hoursFormatter: DateComponentsFormatter = makeFormatter(units: [.hour, .minute, .second])
    private static let minutesFormatter: DateComponentsFormatter = makeFormatter(units: [.minute, .second])

    private static func makeFormatter(units: NSCalendar.Unit) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = units
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }

    func formatDuration(from interval: UInt) -> String {
        if interval > 360 {
            return LocalizedDurationFormatter.hoursFormatter.string(from: TimeInterval(interval)) ?? ""
        } else {
            return LocalizedDurationFormatter.minutesFormatter.string(from: TimeInterval(interval)) ?? ""
        }
    }
}
