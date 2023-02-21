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

public protocol MirrorableEnum {}
extension MirrorableEnum {
    public var mirror: (label: String, params: [String: Any]) {
        let reflection = Mirror(reflecting: self)
        guard reflection.displayStyle == .enum,
            let associated = reflection.children.first else {
                return ("\(self)", [:])
        }
        let values = Mirror(reflecting: associated.value).children
        var valuesArray = [String: Any]()
        for case let item in values where item.label != nil {
            valuesArray[item.label!] = item.value
        }
        return (associated.label!, valuesArray)
    }
}
