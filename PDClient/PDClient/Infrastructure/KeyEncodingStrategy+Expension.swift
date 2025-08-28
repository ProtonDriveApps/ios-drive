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

public extension JSONEncoder {
    convenience init(strategy: JSONEncoder.KeyEncodingStrategy) {
        self.init()
        keyEncodingStrategy = strategy
    }
}

extension JSONEncoder.KeyEncodingStrategy {
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    public static var capitalizeFirstLetter: Self {
        .custom { codingPath in
            guard let lastKey = codingPath.last else {
                fatalError("Coding path no key")
            }
            if lastKey.intValue != nil {
                return lastKey // No change for array key (number)
            }
            let original = lastKey.stringValue
            let capitalized = original.prefix(1).uppercased() + original.dropFirst()
            return Key(stringValue: capitalized) ?? lastKey
        }
    }
}
