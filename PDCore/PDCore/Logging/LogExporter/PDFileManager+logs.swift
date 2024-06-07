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

extension PDFileManager {
    public static func clearLogsDirectory() {
        try? FileManager.default.removeItem(at: PDFileManager.logsDirectory)
    }

    public static func bootstrapLogDirectory() throws {
        _ = try PDFileManager.ensureDirectoryExists(logsWorkingDirectory)
        _ = try PDFileManager.ensureDirectoryExists(logsRotationDirectory)
        _ = try PDFileManager.ensureDirectoryExists(logsArchiveDirectory)
    }

    public static var logsDirectory: URL {
        guard let logsDirectory = try? PDFileManager.getLogsDirectory() else {
            fatalError("Failed to get logs directory")
        }
        return logsDirectory
    }

    public static let logsWorkingDirectory: URL = logsDirectory.appendingPathComponent("1.WorkingDirectory", isDirectory: true)
    public static let logsRotationDirectory: URL = logsDirectory.appendingPathComponent("2.RotationDirectory", isDirectory: true)
    public static let logsArchiveDirectory: URL = logsDirectory.appendingPathComponent("3.ArchiveDirectory", isDirectory: true)
    public static let logsExportDirectory: URL = logsDirectory.appendingPathComponent("ExportDirectory", isDirectory: true)
}
