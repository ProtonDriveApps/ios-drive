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

public protocol FileLogRotator {
    func rotate(_ file: URL)
}

public protocol FileLogExporter {
    func export()
}

public final class FileWritingLogger: LoggerProtocol {
    private let fileManager = FileManager.default
    private let workingDirectory = PDFileManager.logsWorkingDirectory
    private let formatter: ISO8601DateFormatter

    private let system: LogSystem
    private let maxFileSize: UInt64
    private let rotator: FileLogRotator
    private let dateProvider: () -> Date

    private var fileHandle: FileHandle?

    public let logsFileURL: URL

    public init(
        logSystem: LogSystem,
        maxFileSize: UInt64,
        rotator: FileLogRotator,
        formatter: ISO8601DateFormatter = .fileLogFormatter,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.system = logSystem
        self.maxFileSize = maxFileSize
        self.logsFileURL = workingDirectory.appendingPathComponent(logSystem.name + ".log", isDirectory: false)
        self.rotator = rotator
        self.formatter = formatter
        self.dateProvider = dateProvider

        openFile()
    }

    public func log(
        _ level: LogLevel,
        message: String,
        system: LogSystem,
        domain: LogDomain,
        context: LogContext? = nil,
        sendToSentryIfPossible _: Bool, 
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        let logEntry = formatLogEntry(level: level, message: message, domain: domain, context: context)
        writeLogEntry(logEntry)
    }

    private func formatLogEntry(level: LogLevel, message: String, domain: LogDomain, context: LogContext?) -> String {
        let dateTime = formatter.string(from: getDate())
        let version = Constants.clientVersion.map { " | v\($0)" } ?? " | v?.?.?"
        var logLine = "\(dateTime)\(version) | \(domain.name.uppercased()) | \(level.description) | \(message)"
        if let context, !context.debugDescription.isEmpty {
            logLine += " | " + context.debugDescription
        }
        return logLine + "\n"
    }

    private func writeLogEntry(_ entry: String) {
        guard let data = entry.data(using: .utf8) else { return }

        if !fileManager.fileExists(atPath: logsFileURL.path) {
            recreateLostFile()
        }

        guard let fileHandle else { return }

        do {
            try fileHandle.write(contentsOf: data)
            if try fileHandle.offset() >= maxFileSize {
                rotateLogFile()
            }
        } catch {
            // If for some reason we cannot write to the file, we should recreate it
            recreateLostFile()
            Log.error("Error writing to log file", error: error, domain: .logs)
        }
    }

    private func openFile() {
        guard fileHandle == nil else { return }

        do {
            if fileManager.fileExists(atPath: logsFileURL.path) {
                // Open FileHandle of logs file if it exists
                let fileHandle = try FileHandle(forWritingTo: logsFileURL)
                try fileHandle.seekToEnd()
                self.fileHandle = fileHandle
            } else {
                // Create logs file and open FileHandle of logs file if it does not exist
                createIntermediateDirectoriesIfNeeded()
                fileManager.createFile(atPath: logsFileURL.path, contents: nil, attributes: nil)
                try fileManager.secureFilesystemItems(logsFileURL)
                fileHandle = try FileHandle(forWritingTo: logsFileURL)
            }
        } catch {
            fileHandle = nil
        }
    }

    public func rotateLogFile() {
        closeFile()
        rotator.rotate(logsFileURL)
        openFile()
    }

    private func recreateLostFile() {
        closeFile()
        deleteLogFile()
        openFile()
    }

    private func createIntermediateDirectoriesIfNeeded() {
        let directory = logsFileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func deleteLogFile() {
         try? fileManager.removeItem(at: logsFileURL)
     }

    private func closeFile() {
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil
    }

    private func getDate() -> Date {
        dateProvider()
    }

    deinit {
        closeFile()
    }
}
