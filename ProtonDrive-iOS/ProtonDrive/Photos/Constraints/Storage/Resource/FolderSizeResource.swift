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

protocol FolderSizeResource {
    func getSize(at url: URL) throws -> Int
}

enum LocalFolderSizeResourceError: Error {
    case invalidURL
}

final class LocalFolderSizeResource: FolderSizeResource {
    private let fileManager = FileManager.default
    private let resourceKeys = [
        URLResourceKey.isRegularFileKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
    ]

    func getSize(at url: URL) throws -> Int {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: resourceKeys, errorHandler: nil) else {
            throw LocalFolderSizeResourceError.invalidURL
        }

        var totalSize: Int = 0
        for item in enumerator {
            guard let url = item as? URL else {
                throw LocalFolderSizeResourceError.invalidURL
            }
            totalSize += try getItemSize(at: url)
        }
        return totalSize
    }

    private func getItemSize(at url: URL) throws -> Int {
        let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
        guard resourceValues.isRegularFile ?? false else {
            return 0
        }
        return resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0
    }
}
