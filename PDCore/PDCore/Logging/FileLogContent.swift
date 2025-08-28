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
import OSLog

public class FileLogContent: LogContentLoader {

    public let logSource: LogSource = [.app, .extension, .osLogStore]

    public init() {}

    private let fileManager = FileManager.default

    private var subsystems: [LogSystem] {
        #if os(iOS)
        return [LogSystem.iOSApp, LogSystem.iOSFileProvider]
        #else
        return [LogSystem.macOSApp, LogSystem.macOSFileProvider]
        #endif	
    }

    private func fileLog(for source: LogSource) -> FileLog {
        switch source {
        #if os(iOS)
        case .app:
            return .iOSApp
        case .extension:
            return .iOSFileProvider
        #else
        case .app:
            return .macOSApp
        case .extension:
            return .macOSFileProvider
        #endif
        case .osLogStore:
            fatalError("osLogStore does not need specific FileLog.")
        default:
            fatalError("No default FileLog")
        }
    }

    private func urls(for source: LogSource) -> [URL] {
        guard let urls = try? getURLs() else {
            return []
        }

        let filenameWithoutExtension = fileLog(for: source).name.fileName
        /// Check for `name.log` or `name.240125161127236.log` formats
        /// Example: `log-ProtonDriveiOS.log` and `log-ProtonDriveiOS.240125161127236.log`
        let regexp = "\(filenameWithoutExtension)(.\\d{15})*.log"
        return urls
            .filter { $0.pathComponents.last?.hasMatches(for: regexp) ?? false }
            .sorted(by: fileManager.fileCreationDateSort)
    }

    public func loadContent() async throws -> [String] {
        var result: [String] = []

        if logSource.contains(.app) {
            let appResult = try loadLogs(from: self.urls(for: .app))
            result.append(appResult)
        }

        if logSource.contains(.extension) {
            let extensionResult = try loadLogs(from: self.urls(for: .extension))
            result.append(extensionResult)
        }

        if logSource.contains(.osLogStore) {
            let osLogResult = try loadOSLogEntries()
            result.append(osLogResult)
        }
        
        return result
    }

    public func getURLs() throws -> [URL] {
        let logsFolder = try PDFileManager.getLogsDirectory()
        return try fileManager.contentsOfDirectory(at: logsFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    }

    private func loadLogs(from urls: [URL]) throws -> String {
        return try urls.reduce("") { prev, url in
            let contents = try String(contentsOf: url)
            return prev + contents + "\n"
        }
    }

    private func loadOSLogEntries() throws -> String {
        let logEntries = try getLogEntries().map { $0.description }
        return logEntries.joined(separator: "\n")
    }

    private func getLogEntries() throws -> [OSLogEntryLog] {
        let logStore = try OSLogStore(scope: .currentProcessIdentifier)
        let start = logStore.position(date: Date.Past.threeDays())
        let entries = try logStore.getEntries(at: start)

        return entries
            .compactMap { $0 as? OSLogEntryLog }
            .filter { subsystems.map { $0.name }.contains($0.subsystem) }
    }

}
