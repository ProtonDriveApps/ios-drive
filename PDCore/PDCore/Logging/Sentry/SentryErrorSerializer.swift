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

import CoreData
import Foundation

protocol SentryErrorSerializer {
    func serialize(error: NSError) -> String
}

final class SanitizedErrorSerializer: SentryErrorSerializer {
    func serialize(error: NSError) -> String {
        // Remove CoreData objects, since printing them causes crashes (access on wrong thread).
        // Such info should be removed before getting to this point, but we occasionally see these coming anyway.
        let userInfo = error.userInfo.filter { key, value in
            ![NSValidationObjectErrorKey, NSAffectedObjectsErrorKey].contains(key)
        }
        let sanitizedError = NSError(domain: error.domain, code: error.code, userInfo: userInfo)
        return String(describing: sanitizedError)
    }
}
