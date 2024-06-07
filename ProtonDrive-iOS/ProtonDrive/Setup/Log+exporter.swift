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

extension Log {
    static var exporter: FileLogExporter = BlankFileLogExporter()
}

final class BlankFileLogExporter: FileLogExporter {
    func export() { }
}

final class LogsQueueFileLogExporterDecorator: FileLogExporter {
    private let queue = DispatchQueue.logsQueue
    private let decoratee: FileLogExporter

    init(decoratee: FileLogExporter) {
        self.decoratee = decoratee
    }

    // This operation happens rarely, when the user exports logs. It can be blocking.
    func export() {
        queue.sync {
            decoratee.export()
        }
    }
}

final class FileWritingLogerToExporterAdapter: FileLogExporter {
    private let fileManager = FileManager.default
    private let mainProcessLogger: FileWritingLogger
    private let otherProcessesRotator: FileLogRotator

    init(mainProcessLogger: FileWritingLogger, otherProcessesRotator: FileRenamingFileRotatorDecorator) {
        self.mainProcessLogger = mainProcessLogger
        self.otherProcessesRotator = otherProcessesRotator
    }

    private var logsFileURL: URL {
        mainProcessLogger.logsFileURL
    }

    func export() {
        moveLogFilesCreatedByOtherProccessesToTheRotationDirectory()
        exportLogFileFromMainProcessToTheRotationDirectory()
    }

    // Moves and timestamps files created by other processes from the working directory to the rotation directory.
    private func moveLogFilesCreatedByOtherProccessesToTheRotationDirectory() {
        let logFiles = (try? fileManager.contentsOfDirectory(at: PDFileManager.logsWorkingDirectory, includingPropertiesForKeys: nil, options: [])) ?? []
        let otherProcessLogFiles = logFiles.filter { !$0.isHiddenFile }.filter { $0 != logsFileURL }

        for otherProcessFile in otherProcessLogFiles {
            otherProcessesRotator.rotate(otherProcessFile)
        }
    }

    // Exports the log file from the main process to the rotation directory. This involves rotating the logs file, and compressing it.
    private func exportLogFileFromMainProcessToTheRotationDirectory() {
        mainProcessLogger.rotateLogFile()
    }
}
