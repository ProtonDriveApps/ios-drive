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
import PDClient

/// Remove CoreData objects, since printing them causes crashes (access on wrong thread).
/// Such info should be removed before getting to this point, but we occasionally see these coming anyway.
final class SanitizedErrorSerializer {
    func serialize(error: Error) -> String {
        // WARNING: Do not use `error.description`, as it contains `userInfo`, which can contain CoreData objects.

        var result = [String: String]()
        let nsError = error as NSError

        result["localizedDescription"] = error.localizedDescription
        result["localizedFailureReason"] = nsError.localizedFailureReason
        result["localizedRecoverySuggestion"] = nsError.localizedRecoverySuggestion
        result["localizedRecoveryOptions"] = nsError.localizedRecoveryOptions?.joined(separator: ",")
        result["code"] = nsError.code.description
        result["domain"] = nsError.domain
        result["helpAnchor"] = nsError.helpAnchor
        result["underlyingErrors"] = nsError.underlyingErrors.map { serialize(error: $0) }.joined(separator: "; ")

        if !nsError.userInfo.isEmpty {
            let filteredUserInfo = nsError.userInfo.filter { key, value in
                ![
                    // Keys exposed as properties
                    NSLocalizedDescriptionKey,
                    NSLocalizedFailureReasonErrorKey,
                    NSLocalizedRecoverySuggestionErrorKey,
                    NSLocalizedRecoveryOptionsErrorKey,

                    // Keys containing core data objects
                    NSValidationObjectErrorKey,
                    NSAffectedObjectsErrorKey,
                    "NSDetailedErrors"
                ].contains(key)
            }
            result["userInfo"] = String(describing: filteredUserInfo)
        }

        if let rError = (error as? ResponseError) {
            result["userFacing"] = rError.userFacingMessage
            result["httpCode"] = rError.httpCode?.description
            result["responseCode"] = rError.responseCode?.description
            result["responseDictionary"] = rError.responseDictionary?.json(prettyPrinted: true)
            result["bestShotAtReasonableErrorCode"] = rError.bestShotAtReasonableErrorCode.description
            result["isNetworkIssueError"] = rError.isNetworkIssueError.trueOrNil?.description

            if let underlyingError = rError.underlyingError {
                result["underlyingErrors"] = serialize(error: underlyingError)
            }
        }

        if let errorWithDetailedMessage = error as? ErrorWithDetailedMessage {
            result["detailedMessage"] = errorWithDetailedMessage.detailedMessage
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            return jsonString.removingUserName.removingDotNetNoise
        } catch let encodingError {
            return "Encoding error: (\(encodingError)) while logging \"\(error.localizedDescription)\" error"
        }
    }
}

extension Bool {
    var trueOrNil: Bool? {
        return self ? true : nil
    }
}
