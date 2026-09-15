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

public extension ISO8601DateFormatter {
    // Plain formatter with default `formatOptions`: UTC internet date-time without fractional seconds.
    private static let `default`: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
    }()

    // Fallback for ISO8601 strings with fractional seconds (e.g. from Windows/.NET clients),
    // which the default `.withInternetDateTime` options reject. Sub-millisecond digits are truncated.
    private static let fractionalSecondsFallback: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // Static so callers don't get the cascade behaviour disguised as a method on a specific instance.
    static func date(_ string: String?) -> Date? {
        guard let string else {
            return nil
        }
        return `default`.date(from: string) ?? fractionalSecondsFallback.date(from: string)
    }

    static func string(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }
        return `default`.string(from: date)
    }
}
