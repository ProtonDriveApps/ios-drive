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

protocol PhotosDumpStorageResource {
    func store(libraryDump: String, databaseDump: String, cloudDump: String) throws -> [URL]
}

final class ConcretePhotosDumpStorageResource: PhotosDumpStorageResource {
    func store(libraryDump: String, databaseDump: String, cloudDump: String) throws -> [URL] {
        let folderURL = PDFileManager.cleartextCacheDirectory.appendingPathComponent("diagnostics_dump", isDirectory: true)
        try? FileManager.default.removeItem(at: folderURL)
        try? FileManager.default.createDirectory(atPath: folderURL.path, withIntermediateDirectories: true, attributes: nil)
        let libraryDumpURL = folderURL.appendingPathComponent("libraryDump.diag")
        try Data(libraryDump.utf8).write(to: libraryDumpURL)
        let databaseDumpURL = folderURL.appendingPathComponent("databaseDump.diag")
        try Data(databaseDump.utf8).write(to: databaseDumpURL)
        let cloudDumpURL = folderURL.appendingPathComponent("cloudDump.diag")
        try Data(cloudDump.utf8).write(to: cloudDumpURL)
        return [libraryDumpURL, databaseDumpURL, cloudDumpURL]
    }
}
