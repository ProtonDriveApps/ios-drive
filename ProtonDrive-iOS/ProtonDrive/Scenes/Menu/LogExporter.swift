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
import PDCoreIOS
import ZIPFoundation

actor ExportTracker {
    private(set) var progress: ExportProgress = .initialization
    
    func update(progress: ExportProgress) {
        self.progress = progress
    }
}

enum ExportProgress {
    case initialization
    case export
    case creatingDirectory
    case archiving
    case readingPreviousLogs
    case compressing(Int, Int)
    
    var rawValue: String {
        switch self {
        case let .compressing(idx, total):
            return "compressing \(idx)/\(total)"
        default:
            return String(describing: self)
        }
    }
}

final class LogExporter {
    func export(heartbeat: @escaping ((ExportProgress) -> Void)) async throws -> URL {
        Log.info("Will export logs", domain: .logs)
        let tracker = ExportTracker()
        await tracker.update(progress: .export)
        
        let heartbeat = Task {
            while true {
                try? await Task.sleep(for: .seconds(10))
                if Task.isCancelled { break }
                heartbeat(await tracker.progress)
            }
        }
        defer { heartbeat.cancel() }
        
        Log.exporter.export()

        let archiveDirectory = PDFileManager.logsArchiveDirectory
        let exportDirectory = PDFileManager.logsExportDirectory
        let exportZip = exportDirectory.appendingPathComponent("ProtonDriveLogs.zip")

        let fileManager = FileManager.default

        try? fileManager.removeItem(at: exportZip)
        await tracker.update(progress: .creatingDirectory)
        try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        do {
            await tracker.update(progress: .archiving)
            let finalArchive = try Archive(url: exportZip, accessMode: .create)
            
            await tracker.update(progress: .readingPreviousLogs)
            let zipFiles = try fileManager.contentsOfDirectory(at: archiveDirectory, includingPropertiesForKeys: nil)
                .filter { !$0.isHiddenFile && $0.pathExtension == "zip" }
                .sorted { $0.creationDate < $1.creationDate }

            for (idx, zipFile) in zipFiles.enumerated() {
                await tracker.update(progress: .compressing(idx, zipFiles.count))
                guard let archive = try? Archive(url: zipFile, accessMode: .read, pathEncoding: nil) else { continue }

                for entry in archive {
                    // Only decompress `.log` entries
                    guard entry.path.hasSuffix(".log") else { continue }

                    // Write to a temp file
                    let tempURL = exportDirectory.appendingPathComponent(UUID().uuidString + ".log")
                    _ = try archive.extract(entry, to: tempURL)

                    // Add to final zip
                    try finalArchive.addEntry(with: entry.path, fileURL: tempURL, compressionMethod: .deflate)

                    // Delete temp file
                    try? fileManager.removeItem(at: tempURL)
                }
            }
        } catch {
            let progress = await tracker.progress
            UserMessageHandler().handleError(PlainMessageError("\(progress.rawValue), \(error.localizedDescription)"))
            Log.error("Failed to export final logs zip", error: error, domain: .logs)
            throw error
        }

        return exportZip
    }
}

extension LogExporter {
    /// Ensures the logs archive directory only contains `.zip` files.
    /// Converts any remaining `.lzfse` legacy logs to `.zip`.
    /// Returns the archive directory path.
    func prepareArchivedLogsDirectory() -> URL {
        Log.exporter.export()
        return PDFileManager.logsArchiveDirectory
    }
}
