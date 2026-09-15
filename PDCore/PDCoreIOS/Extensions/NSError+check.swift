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

public extension NSError {
    var isNoSpaceOnDevice: Bool {
        return outOfSpaceError != nil
    }

    var outOfSpaceError: NSError? {
        var currentError = self

        while let underlying = currentError.underlyingErrors.first {
            currentError = underlying as NSError
        }
        if currentError.domain == "NSPOSIXErrorDomain" && currentError.code == 28 {
            // No space left on device
            return currentError
        } else if currentError.domain == "NSItemProviderErrorDomain" && currentError.code == -1 {
            // Cannot create a temporary file
            return currentError
        }
        return nil
    }
}
