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
import ZIPFoundation

public final class ArchivingFileCompressor: FileLogRotator {
    private let fileManager = FileManager.default
    private let archiveDirectory: URL
    private let maxBundleSizeMB: Double
    private let logsBundlePrefix: String = "logs_since_"

    public init(
        archiveDirectory: URL = PDFileManager.logsArchiveDirectory,
        maxBundleSizeMB: Double = 9.5
    ) {
        self.archiveDirectory = archiveDirectory
        self.maxBundleSizeMB = maxBundleSizeMB
    }

    public func rotate(_ file: URL) {
        processAllFilesInDirectory(inSource: file.deletingLastPathComponent())
    }

    private func processAllFilesInDirectory(inSource source: URL) {
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
                .filter { !$0.isHiddenFile && $0.pathExtension == "log" }
                .sorted { $0.creationDate < $1.creationDate }

            for file in logFiles {
                try processFile(file)
            }
        } catch {
            SentryClient.shared.recordError("LogCollectionError 😵🗂️. Failed to list files in directory: \(error)")
        }
    }

    private func processFile(_ file: URL) throws {
        let existingZips = try fileManager.contentsOfDirectory(at: archiveDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            .filter { $0.pathExtension == "zip" && $0.lastPathComponent.hasPrefix(logsBundlePrefix) }
            .sorted { $0.creationDate < $1.creationDate }

        if let lastZip = existingZips.last,
           let existingSize = lastZip.fileSize,
           let archive = try? Archive(url: lastZip, accessMode: .update) {

            let sizeMBExisting = Double(existingSize) / (1024 * 1024)

            if sizeMBExisting <= maxBundleSizeMB {
                try archive.addEntry(with: file.lastPathComponent, fileURL: file, compressionMethod: .deflate)
                try fileManager.removeItem(at: file)
                return
            }
        }

        // Create a new zip
        let timestamp = ISO8601DateFormatter.fileLogFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let zipName = "\(logsBundlePrefix)\(timestamp).zip"
        let archiveURL = archiveDirectory.appendingPathComponent(zipName)
        let newArchive = try Archive(url: archiveURL, accessMode: .create)
        try newArchive.addEntry(with: file.lastPathComponent, fileURL: file, compressionMethod: .deflate)
        try fileManager.removeItem(at: file)
    }
}
