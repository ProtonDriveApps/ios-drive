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

/// Providing similar functionality as `DriveError` while keeping the original `domain` and `code`
/// `message` should not contain sensitive data.
public class DomainCodeError: NSError {
    public init(
        error: NSError,
        message: String? = nil,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line) {
        Log.error(
            error: error,
            domain: .restricted,
            sendToSentryIfPossible: false,
            file: file,
            function: function,
            line: line
        )
        let message = "\(error.domain) \(error.code), message: \(message ?? "empty")"
        super.init(domain: error.domain, code: error.code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
