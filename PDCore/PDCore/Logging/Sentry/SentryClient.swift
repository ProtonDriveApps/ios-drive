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
}

public class SentryClient {
    typealias Event = Sentry.Event
    public static let shared = SentryClient()
    
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

    private var isSendingEvent: Atomic<Bool> = .init(false)

    public func start(localSettings: LocalSettings) {
        self.localSettings = localSettings

        SentrySDK.start { [optOutFromCrashReports, sentryEndpoint, environment] options in
            options.dsn = sentryEndpoint
            options.environment = environment
            options.enableCrashHandler = !optOutFromCrashReports
            options.enableAutoPerformanceTracing = false

            // was renamed from enableOutOfMemoryTracking
            options.enableWatchdogTerminationTracking = false
            options.enableAutoBreadcrumbTracking = false
            options.debug = false
            options.beforeSend = { event in
                #if os(macOS)
                let exceptionMessagesToIgnore = ExceptionMessagesExcludedFromSentryCrashReport.allCases.map(\.rawValue)
                if let exceptions = event.exceptions {
                    let exception = exceptions.first { exception in
                        exceptionMessagesToIgnore.contains { exception.value.contains($0) }
                    }
                    if let exception {
                        Log.info("Crash report not sent to Sentry because it contains the following message: \(exception.value)",
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
        let event = Event(level: logEntry.level.toSentryLevel)
        event.message = SentryMessage(formatted: logEntry.message)
        event.extra = logEntry.context?.context ?? [:]
        event.environment = environment
        
        record(event)
    }

    func recordError(_ message: String) {
        let event = Event(level: LogLevel.error.toSentryLevel)
        event.message = SentryMessage(formatted: message)
        event.environment = environment
        
        record(event)
    }

    private func record(_ event: Event) {
        guard !optOutFromCrashReports else { return }
        guard !isSendingEvent.value else {
            return
        }

        isSendingEvent.mutate { $0 = true }
        defer {
            isSendingEvent.mutate { $0 = false }
        }

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
