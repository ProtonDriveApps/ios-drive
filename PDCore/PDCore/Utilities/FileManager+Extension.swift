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

extension FileManager {
    public func secureFilesystemItems(_ url: URL) throws {
        #if os(iOS)
            try (url as NSURL).setResourceValue(URLFileProtection.completeUntilFirstUserAuthentication, forKey: .fileProtectionKey)
            try (url as NSURL).setResourceValue(NSNumber(true), forKey: URLResourceKey.isExcludedFromBackupKey)
        #endif
    }
}

extension FileManager {
    func split(file: URL, maxBlockSize: Int, chunkSize: Int) throws -> [URL] {
        let reader = try FileHandle(forReadingFrom: file)
        defer { reader.closeFile() }
        var writer: FileHandle!
        var blockSizedFiles: [URL] = []
        
        var data = reader.readData(ofLength: chunkSize)
        while !data.isEmpty {
            let blockUrl = file.appendingPathExtension("\(blockSizedFiles.count)")
            if FileManager.default.fileExists(atPath: blockUrl.path) {
                try FileManager.default.removeItem(at: blockUrl)
            }
            FileManager.default.createFile(atPath: blockUrl.path, contents: Data(), attributes: nil)
            writer = try FileHandle(forWritingTo: blockUrl)
            
            while writer.offsetInFile < maxBlockSize - chunkSize, !data.isEmpty {
                autoreleasepool {
                    writer.write(data)
                    data = reader.readData(ofLength: chunkSize)
                }
            }
            writer.closeFile()
            blockSizedFiles.append(blockUrl)
        }

        return blockSizedFiles
    }
    
    func merge(files: [URL], to destination: URL, chunkSize: Int) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil)
        
        let writer = try FileHandle(forWritingTo: destination)
        try files.forEach { blockUrl in
            try autoreleasepool {
                let reader = try FileHandle(forReadingFrom: blockUrl)
                var data = reader.readData(ofLength: chunkSize)
                while !data.isEmpty {
                    autoreleasepool {
                        writer.write(data)
                        data = reader.readData(ofLength: chunkSize)
                    }
                }
                reader.closeFile()
            }
        }
        
        writer.closeFile()
        try files.forEach(FileManager.default.removeItem)
    }
}
