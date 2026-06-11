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
import PDClient
import ProtonCoreDoh
import ProtonCoreLog
import ProtonCoreFeatureFlags
import PMEventsManager

final class LogsConfigurator {
    private var localSettings: LocalSettings
    private var logSystem: LogSystem
    private var defaultHost: String

    init(logSystem: LogSystem, localSettings: LocalSettings, defaultHost: String) {
        self.logSystem = logSystem
        self.localSettings = localSettings
        self.defaultHost = defaultHost
        self.configureLogger()
    }

    deinit {
        disableLogger()
    }

    private func configureLogger() {
        Log.logSystem = logSystem
        #if DEBUG
        Log.logger = makeDebugBuildLogger()
        #else
        Log.logger = makeProductionBuildLogger()
        #endif
        PDClient.logInfo = { Log.info($0, domain: .clientNetworking) }
        PDClient.logError = { Log.error($0, error: nil, domain: .clientNetworking) }
        DispatchQueue.main.async { [defaultHost] in
            PMLog.setExternalLoggerHost(defaultHost)
        }
        PMLog.callback = { message, level in
            switch level {
            case .fatal:
                Log.error(message, error: nil, domain: .coreLibrary, sendToSentryIfPossible: false)
            case .error:
                Log.error(message, error: nil, domain: .coreLibrary, sendToSentryIfPossible: false)
            case .warn:
                Log.warning(message, domain: .coreLibrary)
            case .info:
                Log.info(message, domain: .coreLibrary)
            case .debug:
                Log.debug(message, domain: .coreLibrary)
            case .trace:
                Log.trace(message)
            }
        }
    }

    private func disableLogger() {
        Log.logger = DebugLogger()
        PDClient.logInfo = { _ in }
        PDClient.logError = { _ in }
        DispatchQueue.main.async {
            PMLog.disableExternalLogging()
        }
        PMLog.callback = { message, level in }
    }

    private func makeProductionBuildLogger() -> LoggerProtocol {
        // Trace level logs are not consistently sanitixed, exclude them at the moment
        let levels: [LogLevel] = [.info, .error, .warning, .debug]

        let compoundLogger = CompoundLogger(loggers: [
            makeFileWritingLogger(),
            ProductionLogger(),
        ].compactMap { $0 })

        return AndFilteredLogger(
            logger: compoundLogger,
            domains: LogDomain.iOSDomains,
            levels: Set(levels)
        )
    }

    private func makeDebugBuildLogger() -> LoggerProtocol {
        let compoundLogger = CompoundLogger(loggers: [
            makeFileWritingLogger(),
            DebugLogger(),
        ].compactMap { $0 })

        return AndFilteredLogger(
            logger: compoundLogger,
            domains: LogDomain.iOSDomains,
            levels: [.info, .error, .warning, .debug, .trace]
        )
    }

    private func makeFileWritingLogger() -> LoggerProtocol? {
        // The maximum size of the log file is set to 10MB
        let logMaxFileSize: UInt64 = 10 * 1024 * 1024

        do {
            try PDFileManager.bootstrapLogDirectory()
            let fileLogger = FileWritingLogger(
                logSystem: logSystem,
                maxFileSize: logMaxFileSize,
                rotator: makeFileLogsRotator()
            )
            Log.exporter = makeExporter(fileWritingLogger: fileLogger)
            return LogsQueueDispatchingLogger(logger: fileLogger, queue: .logsQueue)
        } catch {
            // If the log directory cannot be created, we should fall back to a silent logger
            return nil
        }
    }

    private func makeFileLogsRotator() -> FileLogRotator {
        // The maximum size of the log archive is set to 100MB
        let maximumArchiveSize = 100 * 1024 * 1024

        #if TARGET_IS_EXTENSION
        // In extensions, we don't compress the logs, we just prepare them for the app to compress them.
        return CleaningFileLogRotatorDecorator(
            maximumArchiveSize: maximumArchiveSize,
            rotator: FileRenamingFileRotatorDecorator(rotator: BlankFileRotator())
        )
        #else
        return CleaningFileLogRotatorDecorator(
            maximumArchiveSize: maximumArchiveSize,
            rotator: FileRenamingFileRotatorDecorator(
                rotator: LZFSEToZipMigrator(rotator: ArchivingFileCompressor())
            )
        )
        #endif
    }

    // The exporter requires the FileWritingLogger because it writes
    private func makeExporter(fileWritingLogger: FileWritingLogger) -> FileLogExporter {
        if PDCore.Constants.runningInExtension {
            // In extensions, we don't export the logs
            return BlankFileLogExporter()
        } else {
            // We want the export to prepare the logs from other processes as well so they can be exported
            let moveAndRenameRotator = FileRenamingFileRotatorDecorator(rotator: BlankFileRotator())
            let writingToLogerAdapter = FileWritingLogerToExporterAdapter(
                mainProcessLogger: fileWritingLogger,
                otherProcessesRotator: moveAndRenameRotator
            )
            return LogsQueueFileLogExporterDecorator(decoratee: writingToLogerAdapter)
        }
    }

    private var appEnvironment: String {
        switch Constants.clientApiConfig.environment {
        case .black, .blackPayment:
            return "black"
        case .custom(let custom):
            return custom
        default:
            return "production"
        }
    }
}
