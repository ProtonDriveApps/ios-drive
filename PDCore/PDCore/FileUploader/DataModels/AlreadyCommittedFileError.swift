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

struct AlreadyCommittedFileError: LocalizedError, CustomDebugStringConvertible {
    let line: Int
    let file: String

    internal init(file: String = #filePath, line: Int = #line) {
        self.file = (file as NSString).lastPathComponent
        self.line = line
    }

    public var debugDescription: String {
        return self.localizedDescription
    }

    public var errorDescription: String? {
        if Constants.buildType.isBetaOrBelow {
            return "\(type(of: self)) [\(file):\(line)]"
        } else {
            return "File already committed for upload"
        }
    }

    var localizedDescription: String {
        self.errorDescription ?? "An unexpected error occurred."
    }
}
