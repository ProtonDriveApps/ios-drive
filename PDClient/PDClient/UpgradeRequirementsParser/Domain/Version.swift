// Copyright (c) 2026 Proton AG
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

public struct Version: Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init?(_ string: String) {
        let parts = string.split(separator: ".")
        
        guard
            parts.count == 3,
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2])
        else {
            assertionFailure("The version should be parseable")
            return nil
        }
        
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    public var description: String { "\(major).\(minor).\(patch)"}

    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        
        return lhs.patch < rhs.patch
    }
}
