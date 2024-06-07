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

import PDCore
import PDClient
import ProtonCoreLog
import ProtonCoreFeatureFlags
import Combine

final class LogsConfigurator {
    private var cancellables: Set<AnyCancellable> = []

    private var featureFlags: LocalSettings
    private var logSystem: LogSystem

    init(logSystem: LogSystem, featureFlags: LocalSettings) {
        self.logSystem = logSystem
        self.featureFlags = featureFlags
        configureLogger()

        // Creates the logger exporter the first time the users logs in into the app
        featureFlags.publisher(for: \.logCollectionEnabled)
            .removeDuplicates()
            .filter { $0 == true } // Only if we go from not enabled to enabled, roll-out flag
            .removeDuplicates() // Just once
            .filter { _ in Log.exporter is BlankFileLogExporter } // After the first login if we have not initiated the exporter we do it here
            .sink { [weak self] _ in
                guard let self = self else { return }
                configureLogger()
            }
            .store(in: &cancellables)
    }

    private func configureLogger() {
        Log.configuration = LogConfiguration(system: logSystem)
        #if DEBUG
        Log.logger = makeDebugBuildLogger()
        #else
        Log.logger = makeProductionBuildLogger()
        #endif
        PDClient.log = { Log.info($0, domain: .clientNetworking) }
        PMLog.setEnvironment(environment: appEnvironment)
    }

    private func makeProductionBuildLogger() -> LoggerProtocol {
        let compoundLogger = CompoundLogger(loggers: [
            makeFeatureFlagEnabledLogger(),
            ProductionLogger(),
        ])

        return AndFilteredLogger(
            logger: compoundLogger,
            domains: LogDomain.default,
            levels: [.info, .error, .warning]
        )
    }

    private func makeDebugBuildLogger() -> LoggerProtocol {
        let compoundLogger = CompoundLogger(loggers: [
            makeFeatureFlagEnabledLogger(),
            DebugLogger(),
        ])

        return AndFilteredLogger(
            logger: compoundLogger,
            domains: LogDomain.default,
            levels: [.info, .error, .warning, .debug]
        )
    }

    private func makeFeatureFlagEnabledLogger() -> LoggerProtocol {
        guard featureFlags.logCollectionEnabled == true && !(featureFlags.logCollectionDisabled == true) else {
            return SilentLogger()
        }

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
            let featureFlagsEnabledLogger = FeatureFlagsEnablesLogsCollectionLoggerDecorator(decoratee: fileLogger, store: featureFlags)
            return LogsQueueDispatchingLogger(logger: featureFlagsEnabledLogger, queue: .logsQueue)
        } catch {
            // If the log directory cannot be created, we should fall back to a silent logger
            return SilentLogger()
        }
    }

    private func makeFileLogsRotator() -> FileLogRotator {
        // The maximum size of the log archive is set to 100MB
        let maximumArchiveSize = 100 * 1024 * 1024

        if PDCore.Constants.runningInExtension {
            // In extensions, we don't compress the logs, we just prepare them for the app to compress them.
            return CleaningFileLogRotatorDecorator(
                maximumArchiveSize: maximumArchiveSize,
                rotator: FileRenamingFileRotatorDecorator(rotator: BlankFileRotator())
            )
        } else {
            // In the main app, we compress the logs to save space.
            return CleaningFileLogRotatorDecorator(
                maximumArchiveSize: maximumArchiveSize,
                rotator: FileRenamingFileRotatorDecorator(rotator: ArchivingFileCompressor())
            )
        }
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
