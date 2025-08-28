// Copyright (c) 2024 Proton AG
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

public extension String {
    func toHex() -> String {
        let data = Data(utf8)
        return data.map { String(format: "%02x", $0) }.joined()
    }

    func preg_replace(
        pattern: String,
        with replacement: String,
        maxReplacement: Int? = nil,
        options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    ) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            var modifiedStr = self as NSString
            let range = NSRange(location: 0, length: (self as NSString).length)
            var matches = regex.matches(in: self, range: range)
            if let maxReplacement {
                matches = Array(matches.prefix(upTo: maxReplacement))
            }
            for match in matches.reversed() {
                let range = match.range
                modifiedStr = modifiedStr.replacingCharacters(in: range, with: replacement) as NSString
            }
            return modifiedStr as String
        } catch {
            return self
        }
    }
}
