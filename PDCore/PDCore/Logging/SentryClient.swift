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

import os.log
import Foundation
import Sentry

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
        "https://d673e48788724e299a2dc4cd2cf004f5@sentry-new.protontech.ch/15" // drive
    }
    
    private var environment: String {
        "production"
    }
    
    public func start(localSettings: LocalSettings) {
        self.localSettings = localSettings
        
        SentrySDK.start { [optOutFromCrashReports, sentryEndpoint, environment] options in
            options.dsn = sentryEndpoint
            options.environment = environment
            options.enableCrashHandler = !optOutFromCrashReports
            options.enableAutoPerformanceTracking = false
            options.enableOutOfMemoryTracking = false
            options.debug = false
        }
    }
    
    func recordError(_ error: NSError) {
        guard !optOutFromCrashReports else { return }
        
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: error.messageForTheUser)
        event.extra = [
            "Code": error.code,
            "Description": String(describing: error),
            "Underlying": error.underlyingErrors.map(String.init(describing:))
        ]
        SentrySDK.capture(event: event)
    }
    
    func recordTelemetry() {
        guard !optOutFromTelemetry else { return }
        
        assertionFailure("Not implemented yet")
    }
}
