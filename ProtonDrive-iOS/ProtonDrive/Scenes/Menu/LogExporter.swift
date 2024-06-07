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

class LogExporter {
    func export() async -> URL {
        // Will synchronously compress the logs and leave them in the archive directory
        Log.exporter.export()

        let archiveDirectory = PDFileManager.logsArchiveDirectory
        let exportDirectory = PDFileManager.logsExportDirectory

        // Ensure the export directory exists
        try? FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true, attributes: nil)

        // Retrieve and unarchive each non-hidden file individually
        unarchiveFilesIndividually(from: archiveDirectory, to: exportDirectory)
        return exportDirectory
    }

    private func unarchiveFilesIndividually(from sourceDirectory: URL, to destinationDirectory: URL) {
        let fileManager = FileManager.default
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)

            for file in directoryContents where !file.isHiddenFile {
                try Archiver.unarchive(file, to: destinationDirectory)
            }
        } catch {
            Log.error("Failed to unarchive log file: \(error.localizedDescription)", domain: .logs)
        }
    }
}
