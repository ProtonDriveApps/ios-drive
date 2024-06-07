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

public enum FileLog: String {
    case iOSApp
    case iOSFileProvider
    case macOSApp
    case macOSFileProvider

    var name: String {
        switch self {
        case .iOSApp:
            return "log-ProtonDriveiOS.log"
        case .iOSFileProvider:
            return "log-ProtonDriveFileProvideriOS.log"
        case .macOSApp:
            return "log-ProtonDriveMac.log"
        case .macOSFileProvider:
            return "log-ProtonDriveFileProviderMac.log"
        }
    }
}

public final class FileLogger: FileLoggerProtocol {

    /// After log file size reaches 1MB in size it is moved to archive and new log file is created
    public let maxFileSize = 1024 * 1024

    /// Maximum number of log files that were rotated. This number doesn't include the main log file where app is writing it's logs.
    public let maxArchivedFilesCount = 1

    private var fileHandle: FileHandle?

    private var currentSize: UInt64 {
        guard let size = try? fileHandle?.seekToEnd() else {
            return 0
        }
        return size
    }

    private let fileManager = FileManager.default

    private let queue: DispatchQueue = DispatchQueue.init(label: "FileLogger", qos: .background)
    
    private let compressedLogsDisabled: () -> Bool

    private var fileURL: URL? {
        guard let logsDirectory = try? PDFileManager.getLogsDirectory() else {
            return nil
        }
        return logsDirectory.appendingPathComponent(fileLogName, isDirectory: false)
    }

    // TODO: https://jira.protontech.ch/browse/DRVIOS-2126
    private var fileLogName: String {
        var name: String = "log-ProtonDrive"
        if PDCore.Constants.runningInExtension {
            name += Platform.appRunningOniOS ? "FileProvideriOS" : "FileProviderMac"
        } else {
            name += Platform.appRunningOniOS ? "iOS" : "Mac"
        }
        return name + ".log"
    }
    
    private let tempFileDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYMMddHHmmssSSS"
        return dateFormatter
    }()

    public init(process: FileLog, compressedLogsDisabled: @escaping () -> Bool) {
        self.compressedLogsDisabled = compressedLogsDisabled
    }

    deinit {
        try? closeFile()
    }

    // the file logger never sends to sentry, regardless of the parameter value
    public func log(_ level: LogLevel, message: String, system: LogSystem, domain: LogDomain, sendToSentryIfPossible _: Bool) {
        self.queue.async { [weak self] in
            let dateTime = ISO8601DateFormatter.fileLogFormatter.string(Date())!
            var text = "\(dateTime)"
            text += " | \(ProcessInfo.processInfo.processIdentifier)"
            if let clientVersion = Constants.clientVersion {
                text += " | v\(clientVersion) "
            }
            text += "| \(system.name) | \(domain.name.uppercased()) | \(level.description) | \(message)"

            let lineSeparator = "\n"
            if let data = (text + lineSeparator).data(using: .utf8) {
                do {
                    guard let self = self else { return }
                    try self.getFileHandleAtTheEndOfFile()?.write(contentsOf: data)
                    try self.rotateLogFileIfNeeded()
                } catch {
                    // swiftlint:disable:next no_print
                    print("🔴🔴 Error writing to file: \(error)")
                }
            }
        }
    }

    // the file logger never sends to sentry, regardless of the parameter value
    public func log(_ error: NSError, system: LogSystem, domain: LogDomain, sendToSentryIfPossible _: Bool) {
        let message = error.localizedDescription
        log(.error, message: message, system: system, domain: domain, sendToSentryIfPossible: false)
    }

    public func openFile() throws {
        try? closeFile()
        guard let logsDirectory = try? PDFileManager.getLogsDirectory(), let fileURL = self.fileURL else {
            return
        }

        if let recentTempFile = try? tempFiles().last {
            fileHandle = try FileHandle(forWritingTo: recentTempFile)
        } else {
            let tempFileURL = fileURL.deletingPathExtension().appendingPathExtension(tempFileDateFormatter.string(from: Date()) + ".log")

            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)

            if !fileManager.fileExists(atPath: tempFileURL.path) {
                fileManager.createFile(atPath: tempFileURL.path, contents: nil, attributes: nil)
                try fileManager.secureFilesystemItems(tempFileURL)
            }
            fileHandle = try FileHandle(forWritingTo: tempFileURL)
        }

    }

    public func closeFile() throws {
        guard let fileHandle = fileHandle else {
            return
        }
        try fileHandle.synchronize()
        try fileHandle.close()

        self.fileHandle = nil
    }

    private func tempFiles() throws -> [URL] {
        guard let fileURL = self.fileURL else {
            return []
        }
        let logsDirectory = try PDFileManager.getLogsDirectory()
        let filenameWithoutExtension = fileURL.deletingPathExtension().pathComponents.last ?? "ProtonDrive"
        let tempFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathComponents.last?.hasMatches(for: "\(filenameWithoutExtension).\\d{15}.log") ?? false }
        return tempFiles.sorted(by: fileManager.fileCreationDateSort)
    }

    private func getFileHandleAtTheEndOfFile() -> FileHandle? {
        if fileHandle == nil {
            do {
                try openFile()
                try fileHandle?.seekToEnd()
            } catch {
                return nil
            }
        }
        return fileHandle
    }

    public func rotateLogFileIfNeeded() throws {
        guard currentSize > maxFileSize else {
            return
        }

        try closeFile()
        try moveToNextFile()
        try removeOldFiles()
    }

    private func moveToNextFile() throws {
        guard let fileURL = self.fileURL else { return }
        let logsDirectory = try PDFileManager.getLogsDirectory()
        let filenameWithoutExtension = fileURL.deletingPathExtension().pathComponents.last ?? "ProtonDrive"

        let formattedFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathComponents.last?.hasMatches(for: "\(filenameWithoutExtension).\\d{15}.log") ?? false }

        guard let currentFileURL = formattedFiles.first else { return }
        #if os(macOS)
        try PDFileManager.appendLogsWithCompressionIfEnabled(from: currentFileURL, to: fileURL, compressionDisabled: compressedLogsDisabled)
        #else
        try PDFileManager.appendFileContents(from: currentFileURL, to: fileURL)
        #endif
    }

    private func removeOldFiles() throws {
        guard let fileURL = self.fileURL else {
            return
        }
        let logsDirectory = try PDFileManager.getLogsDirectory()
        let filenameWithoutExtension = fileURL.deletingPathExtension().pathComponents.last ?? "ProtonDrive"
        let oldFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathComponents.last?.hasMatches(for: "\(filenameWithoutExtension).\\d{15}.log") ?? false }
        let sortedFiles = oldFiles.sorted(by: fileManager.fileCreationDateSort)
        
        try sortedFiles.forEach { url in
            try fileManager.removeItem(at: url)
        }
    }
}

private extension Logger {

    func log(message: String, from level: LogLevel) {
        switch level {
        case .error:
            error("\(message, privacy: .public)")
        case .warning:
            warning("\(message, privacy: .public)")
        case .info:
            notice("\(message, privacy: .public)")
        case .debug:
            debug("\(message, privacy: .public)")
        }
    }
}
