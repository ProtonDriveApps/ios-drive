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
import PDCore

public protocol FolderSizeResource {
    func isSizeOverLimit() -> Bool
    func clearFolder()
    func usedSize() -> Int
}

public final class PhotoCacheFolderSizeResource: FolderSizeResource {
    let cacheFolderURL: URL
    let fileManager: FileManager
    let storageSizeLimit: Int

    public init(fileManager: FileManager = .default, storageSizeLimit: Int) {
        cacheFolderURL = PDFileManager.cleartextPhotosCacheDirectory
        self.fileManager = fileManager
        self.storageSizeLimit = storageSizeLimit
    }

    public func usedSize() -> Int {
        fileManager.folderSize(at: cacheFolderURL)
    }

    public func isSizeOverLimit() -> Bool {
        let size = fileManager.folderSize(at: cacheFolderURL)
        let isOverLimit = size > storageSizeLimit
        if isOverLimit {
            Log.debug("Size is over limit, size: \(size)", domain: .photosProcessing)
        }
        return isOverLimit
    }

    public func clearFolder() {
        do {
            try fileManager.removeItem(atPath: cacheFolderURL.path)
            let url = cacheFolderURL
            PDFileManager.createIfNeeded(url)
        } catch {
            Log.error("Clean upload cache failed", error: error, domain: .photosProcessing)
        }
    }
}

private extension FileManager {
    func folderSize(at folderURL: URL) -> Int {
        var size: Int = 0

        if let enumerator = enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: nil
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    if fileURL.lastPathComponent == ".DS_Store" {
                        continue
                    }
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if resourceValues.isRegularFile == true, let fileSize = resourceValues.fileSize {
                        size += fileSize
                    }
                } catch {
                    Log.error("Fail to read file size", error: error, domain: .photosProcessing)
                }
            }
        }

        return size
    }
}
