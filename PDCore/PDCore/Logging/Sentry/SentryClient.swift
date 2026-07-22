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
import Sentry
import PDClient
import ProtonCoreUtilities

public enum ExceptionMessagesExcludedFromSentryCrashReport: String, CaseIterable {
    case appCoordinatorErrorWhileStartingApp = "Terminate after domains disconnection"
    case keychainAccessErrored = "Crashing because of keychain access error"
    case toggledRuntimeConfigFile = "Toggled runtime config file"
}

public class SentryClient {
    typealias Event = Sentry.Event
    public static let shared = SentryClient()
    public static let sentryClientFilePath = URL(fileURLWithPath: #file).deletingPathExtension().lastPathComponent
    
    private var localSettings: LocalSettings?
    private var optOutFromCrashReports: Bool {
        localSettings?.optOutFromCrashReports == true
    }
    private var optOutFromTelemetry: Bool {
        localSettings?.optOutFromTelemetry == true
    }

    private var sentryEndpoint: String {
        #if os(macOS)
        "https://6d203fc5b3a5403b8c95d6100be9994e@drive-api.proton.me/core/v4/reports/sentry/40" // drive macOS
        #else
        "https://d673e48788724e299a2dc4cd2cf004f5@drive-api.proton.me/core/v4/reports/sentry/15" // drive iOS
        #endif
    }
    
    private var environment: String {
#if DEBUG
        "dev_001"
#else
        "production"
#endif
    }

    public func start(localSettings: LocalSettings) {
        self.localSettings = localSettings

        SentrySDK.start { [optOutFromCrashReports, sentryEndpoint, environment] options in
            options.dsn = sentryEndpoint
            options.environment = environment
            options.enableCrashHandler = !optOutFromCrashReports
            options.enableAutoPerformanceTracing = false

            #if os(iOS)
                // was renamed from enableOutOfMemoryTracking
                options.enableWatchdogTerminationTracking = true
            #else
                // was renamed from enableOutOfMemoryTracking
                options.enableWatchdogTerminationTracking = false
            #endif
            options.enableAutoBreadcrumbTracking = false
            options.debug = false
            options.beforeSend = { event in
                #if os(macOS)
                let exceptionMessagesToIgnore = ExceptionMessagesExcludedFromSentryCrashReport.allCases.map(\.rawValue)
                // this strange dance of casting to NSArray and back was introduced to hopefully remove the cryptic
                // Fatal error: NSArray element failed to match the Swift Array Element type. Expected SentryException but found SentryException
                if let exceptions = event.exceptions {
                    let exception = exceptions
                        .compactMap { $0 as Sentry.Exception }
                        .first { exception in
                            guard let value = exception.value else { return false }
                            return exceptionMessagesToIgnore.contains { value.contains($0) }
                        }
                    if let value = exception?.value {
                        Log.info("Crash report not sent to Sentry because it contains the following message: \(value)",
                                 domain: .diagnostics)
                        return nil
                    }
                }
                #endif
                
                // It's critical that we avoid Sentry being reliant on the keychain so
                // that we can report errors even when the keychain is inaccessible.
                guard let userId = localSettings.userId else {
                    return event
                }
                event.user = User(userId: userId)
                return event
            }
        }
    }

    func record(logEntry: StructuredLogEntry) {
        guard logEntry.file != Self.sentryClientFilePath else {
            // drop the logs from within the SentryClient file itself, to avoid the possible loop
            return
        }
        var extra = logEntry.context?.jsonDictionary ?? [:]
        extra["callSite"] = "[\(logEntry.threadNumber)] \(logEntry.file).\(logEntry.function):\(logEntry.line)"
        let event = Event(level: logEntry.level.toSentryLevel)
        event.message = SentryMessage(formatted: logEntry.message)
        event.extra = extra
        event.environment = environment
        event.tags = ["domain": logEntry.domain.name]
        record(event)
    }

    func recordError(_ message: String, system: LogSystem, domain: LogDomain,
                     file: String = #file, function: String = #function, line: Int = #line) {
        let logEntry = StructuredLogEntry(
            level: .error,
            message: message,
            timestamp: Log.formattedTime,
            threadNumber: Thread.current.number.description,
            system: system,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: true,
            file: URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent,
            function: function,
            line: line
        )
        record(logEntry: logEntry)
    }

    private func record(_ event: Event) {
        guard !optOutFromCrashReports else { return }

        let id = SentrySDK.capture(event: event)
        if id == SentryId.empty {
            Log.info("Sending to Sentry failed. Event: \(event.message ?? event.eventId)", domain: .diagnostics)
        }
    }

    func recordTelemetry() {
        guard !optOutFromTelemetry else { return }
        
        assertionFailure("Not implemented yet")
    }
}

private extension LogLevel {
    var toSentryLevel: SentryLevel {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        case .debug: return .debug
        case .trace: return .none // Traces are never sent to Sentry
        }
    }
}
