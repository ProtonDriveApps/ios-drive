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

public enum URLConsistencyError: Error, LocalizedError {
    case noURLSize
    case urlSizeMismatch

    public var errorDescription: String? {
        switch self {
        case .noURLSize:
            return "Can't get file size for URL"
        case .urlSizeMismatch:
            return "The original URL's size does not match the copy's size"
        }
    }
}

public extension URL {
    var fileSize: Int? {
        // Returns nil if a folder (including package resource "files")
        return try? resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    func getFileSize() throws -> Int {
        guard let fileSize else {
            throw URLConsistencyError.noURLSize
        }

        return fileSize
    }

    var contentModificationDate: Date? {
        return try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Returns the last modification date of the file, or the earliest date if the file doesn't exist
    var lastModificationDate: Date {
        let modificationDate = try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return modificationDate ?? Date(timeIntervalSince1970: .zero)
    }
}
