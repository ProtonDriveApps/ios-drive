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
import ZIPFoundation

public final class LZFSEToZipMigrator: FileLogRotator {
    private let rotator: FileLogRotator
    private let archiveDirectory: URL
    private let fileManager: FileManager

    public init(rotator: FileLogRotator, archiveDirectory: URL = PDFileManager.logsArchiveDirectory, fileManager: FileManager = .default) {
        self.rotator = rotator
        self.archiveDirectory = archiveDirectory
        self.fileManager = fileManager
    }

    public func rotate(_ file: URL) {
        do {
            let allFiles = try fileManager.contentsOfDirectory(at: archiveDirectory, includingPropertiesForKeys: [.fileSizeKey])

            let lzfseFiles = allFiles.filter { !$0.isHiddenFile && $0.pathExtension == "lzfse" }
            let orphanedFiles = allFiles.filter { !$0.isHiddenFile && !$0.lastPathComponent.hasPrefix("logs_since") && !$0.lastPathComponent.hasPrefix("logs_migrated_") && $0.pathExtension != "lzfse" }

            guard !lzfseFiles.isEmpty || !orphanedFiles.isEmpty else {
                rotator.rotate(file)
                return
            }

            let timestamp = ISO8601DateFormatter.fileLogFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let zipFile = archiveDirectory.appendingPathComponent("logs_migrated_\(timestamp).zip")

            let archive = try Archive(url: zipFile, accessMode: .create)

            // ✅ Migrate .lzfse
            for lzfseFile in lzfseFiles {
                let tempFolder = archiveDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                do {
                    try fileManager.createDirectory(at: tempFolder, withIntermediateDirectories: true)

                    try Archiver.unarchive(lzfseFile, to: tempFolder)

                    let contents = try fileManager.contentsOfDirectory(at: tempFolder, includingPropertiesForKeys: [.fileSizeKey])
                    for migratedFile in contents {
                        try archive.addEntry(with: migratedFile.lastPathComponent, fileURL: migratedFile, compressionMethod: .deflate)
                    }

                    try fileManager.removeItem(at: lzfseFile)
                    Log.debug("Migrated \(lzfseFile.lastPathComponent) to \(zipFile.lastPathComponent)", domain: .logs)

                } catch {
                    Log.error("Failed to migrate \(lzfseFile.lastPathComponent)", error: error, domain: .logs)
                }

                // ✅ Always try to remove temp folder
                try? fileManager.removeItem(at: tempFolder)
            }

            // ✅ Migrate orphaned files
            for logFile in orphanedFiles {
                do {
                    try archive.addEntry(with: logFile.lastPathComponent, fileURL: logFile, compressionMethod: .deflate)
                    try fileManager.removeItem(at: logFile)
                    Log.debug("Migrated orphaned \(logFile.lastPathComponent) to \(zipFile.lastPathComponent)", domain: .logs)
                } catch {
                    Log.error("Failed to migrate orphaned \(logFile.lastPathComponent)", error: error, domain: .logs)
                }
            }
        } catch {
            Log.error("Failed to scan archive directory for legacy logs", error: error, domain: .logs)
        }

        rotator.rotate(file)
    }
}
