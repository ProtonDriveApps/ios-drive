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

public struct NukingCacheError: LocalizedError, CustomDebugStringConvertible {
    public let message: String
    public let file: String
    public let line: String

    public init(_ message: String, file: String = #filePath, line: Int = #line) {
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.line = String(line)
    }

    public init(_ error: Error, file: String = #filePath, line: Int = #line) {
        self.init(error.localizedDescription, file: file, line: line)
    }

    public init(withDomainAndCode error: Error, message: String? = nil, file: String = #filePath, line: Int = #line) {
        let error = error as NSError
        let message = "\(error.domain) \(error.code), message: \(message ?? "empty")"
        self.init(message, file: file, line: line)
    }

    public var errorDescription: String? {
        if Constants.buildType.isBetaOrBelow {
            return debugDescription
        }

        return message
    }

    public var debugDescription: String {
        message + "\(file) - \(line)"
    }
}
