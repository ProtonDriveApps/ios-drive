// Copyright (c) 2025 Proton AG
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

/// Only used for logging errors. Should only be injected while mainKey is not available
public class LockedDriveStringCryptoTransformer: ValueTransformer {
    override public class func transformedValueClass() -> AnyClass {
        return NSData.self
    }

    override public class func allowsReverseTransformation() -> Bool {
        return true
    }

    override public func transformedValue(_ value: Any?) -> Any? {
        Log.error("Invoking string crypto transformer before main key is available.", error: nil, domain: .encryption)
        return nil
    }

    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        Log.error("Invoking reverse string crypto transformer before main key is available.", error: nil, domain: .encryption)
        return nil
    }
}
