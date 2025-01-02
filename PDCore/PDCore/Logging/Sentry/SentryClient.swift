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
import ProtonCoreUtilities
import PDClient

public class SentryClient {
    typealias Event = Sentry.Event
    public static let shared = SentryClient()
    
    private var localSettings: LocalSettings?
    private let serializer: SentryErrorSerializer = SanitizedErrorSerializer()
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
        "production"
    }
    
    public func start(localSettings: LocalSettings, clientGetter: @escaping () -> PDClient.Client?) {
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
                guard let client = clientGetter(),
                      let credential = client.credentialProvider.clientCredential() else {
                    return event
                }

                event.user = User(userId: credential.userID)
                return event
            }
        }
    }
    
    func record(level: LogLevel, errorOrMessage: Either<NSError, String>) {
        guard !optOutFromCrashReports else { return }
        
        let event = Event(level: level.toSentryLevel)
        switch errorOrMessage {
        case .left(let error):
            event.message = SentryMessage(formatted: error.localizedDescription)
            event.extra = [
                "Code": error.code,
                "Description": serializer.serialize(error: error),
                "Underlying": error.underlyingErrors.map { serializer.serialize(error: $0 as NSError) }
            ]
        case .right(let message):
            event.message = SentryMessage(formatted: message)
        }
        
        SentrySDK.capture(event: event)
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
        }
    }
}
