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

public extension ByteCountFormatter {

    private static let storageSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.formattingContext = .standalone
        formatter.allowsNonnumericFormatting = true
        formatter.zeroPadsFractionDigits = false
        formatter.includesUnit = true
        formatter.isAdaptive = false
        return formatter
    }()

    static func storageSizeString(forByteCount byteCount: Int64) -> String {
        storageSizeFormatter.string(fromByteCount: byteCount)
    }

    static func storageSizeString(forByteCount byteCount: Double) -> String {
        storageSizeFormatter.string(fromByteCount: Int64(byteCount))
    }
}
