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

extension DriveObservabilityIntegrityFileSize {
    static func from(_ fileSize: Int64) -> Self {
        switch fileSize {
        case ...1024: // <= 1 KB
            return .lessThen1KB
        case ...1048576: // <= 1 MB
            return .between1KBAnd1MB
        case ...4194304: // <= 4 MB
            return .between1MBAnd4MB
        case ...33554432: // <= 33 MB
            return .between4MBAnd33MB
        case ...1073741824: // <= 1 GB
            return .between33MBAnd1GB
        case 1073741824...: // > 1 GB
            return .over1GB
        default:
            assertionFailure("Unsupported file size \(fileSize)")
            return .lessThen1KB
        }
    }
}
