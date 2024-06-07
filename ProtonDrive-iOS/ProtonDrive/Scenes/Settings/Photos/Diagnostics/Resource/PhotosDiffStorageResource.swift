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
import PDCore

protocol PhotosDiffStorageResource {
    func store(libraryStorageDiff: String, storageCloudDiff: String, libraryCloudDiff: String) throws -> [URL]
}

final class ConcretePhotosDiffStorageResource: PhotosDiffStorageResource {
    
    func store(libraryStorageDiff: String, storageCloudDiff: String, libraryCloudDiff: String) throws -> [URL] {
        let folderURL = PDFileManager.cleartextCacheDirectory.appendingPathComponent("diagnostics_diff", isDirectory: true)
        try? FileManager.default.removeItem(at: folderURL)
        try? FileManager.default.createDirectory(atPath: folderURL.path, withIntermediateDirectories: true, attributes: nil)
        
        var urls = [URL]()
        if !libraryStorageDiff.isEmpty {
            let libraryStorageDiffURL = folderURL.appendingPathComponent("libraryStorageDiff.diag")
            try Data(libraryStorageDiff.utf8).write(to: libraryStorageDiffURL)
            urls.append(libraryStorageDiffURL)
        }
        if !storageCloudDiff.isEmpty {
            let storageCloudDiffURL = folderURL.appendingPathComponent("storageCloudDiff.diag")
            try Data(storageCloudDiff.utf8).write(to: storageCloudDiffURL)
            urls.append(storageCloudDiffURL)
        }
        if !libraryCloudDiff.isEmpty {
            let libraryCloudDiffURL = folderURL.appendingPathComponent("libraryCloudDiff.diag")
            try Data(libraryCloudDiff.utf8).write(to: libraryCloudDiffURL)
            urls.append(libraryCloudDiffURL)
        }
        return urls
    }
}
