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
import PDClient
import UserNotifications

public struct LogSystem: Equatable {
    public let name: String

    public init(suffix: String) {
        name = ["ch.proton.drive" + suffix].joinedNonEmpty(separator: ".")
    }

    public static let `default` = LogSystem(suffix: "")
    public static let iOSApp = LogSystem(suffix: ".ios.app")
    public static let iOSFileProvider = LogSystem(suffix: ".ios.fileProvider")
    public static let macOSApp = LogSystem(suffix: "macos.app")
    public static let macOSFileProvider = LogSystem(suffix: "macos.fileProvider")
}

extension LogSystem {

    public var suffix: String {
        guard let range = name.range(of: "ch.proton.drive")  else {
            return ""
        }
        return name[range.upperBound...].trimmingCharacters(in: .whitespaces)
    }
}

public struct LogDomain: Equatable, Hashable {
    public let name: String

    private init(name: String) {
        self.name = name
    }

    public static let application = LogDomain(name: "application")
    public static let networking = LogDomain(name: "networking")
    public static let uploader = LogDomain(name: "uploader")
    public static let downloader = LogDomain(name: "downloader")
    public static let encryption = LogDomain(name: "encryption")
    public static let events = LogDomain(name: "events")
    public static let backgroundTask = LogDomain(name: "backgroundTask")
    public static let photoPicker = LogDomain(name: "photoPicker")
    public static let photosUI = LogDomain(name: "photosUI")
    public static let photosProcessing = LogDomain(name: "photosProcessing")
    public static let storage = LogDomain(name: "storage")
    public static let fileManager = LogDomain(name: "fileManager")
    public static let fileProvider = LogDomain(name: "fileProvider")
    public static let syncing = LogDomain(name: "syncing")
    public static let clientNetworking = LogDomain(name: "clientNetworking")
    public static let trustKit = LogDomain(name: "trustKit")
    public static let telemetry = LogDomain(name: "telemetry")
    public static let featureFlags = LogDomain(name: "featureFlags")
    public static let thumbnails = LogDomain(name: "thumbnails")
    public static let updater = LogDomain(name: "uploader")
    public static let forceRefresh = LogDomain(name: "forceRefresh")
    public static let sessionManagement = LogDomain(name: "sessionManagement")
    public static let sharing = LogDomain(name: "sharing")
    public static let offlineAvailable = LogDomain(name: "offlineAvailable")
    public static let diagnostics = LogDomain(name: "diagnostics")
    public static let ipc = LogDomain(name: "ipc")
    public static let logs = LogDomain(name: "logs")
    public static let protonDocs = LogDomain(name: "protonDocs")
    public static let loadTesting = LogDomain(name: "loadTesting")
    public static let contact = LogDomain(name: "contact")
    public static let ddk = LogDomain(name: "ddk")

    public static let `default`: Set<LogDomain> = [
        .application,
        .encryption,
        .events,
        .networking,
        .uploader,
        .backgroundTask,
        .photosProcessing,
        .clientNetworking,
        .trustKit,
        .telemetry,
        .featureFlags,
        .updater,
        .forceRefresh,
        .sessionManagement,
        .sharing,
        .offlineAvailable,
        .diagnostics,
        .ipc,
        .logs,
        .protonDocs,
        .loadTesting,
        .ddk
    ]
    
    public static func macOSDebugDomains(appending: LogDomain...) -> Set<LogDomain> {
        Set([.application,
             .encryption,
             .events,
             .networking,
             .uploader,
             .downloader,
             .storage,
             .clientNetworking,
             .featureFlags,
             .forceRefresh,
             .sessionManagement,
             .diagnostics,
             .fileProvider,
             .fileManager] + appending)
    }
}

public enum LogLevel: String {
    case error
    case warning
    case info
    case debug

    public static let `default`: Set<LogLevel> = [
//        .debug,
//        .info,
        .warning,
        .error,
    ]
}

extension LogLevel {

    var description: String {
        self.rawValue.uppercased()
    }
}

public struct LogConfiguration {
    public let system: LogSystem

    public init(system: LogSystem) {
        self.system = system
    }

    public static let `default` = LogConfiguration(system: .default)
}

public class Log {
    public static var logger: LoggerProtocol = SilentLogger()
    public static var configuration: LogConfiguration = .default

    // the debug logs are not sent to sentry by default
    public static func debug(_ message: String, domain: LogDomain, sendToSentryIfPossible: Bool = false) {
        logger.log(.debug, message: message, system: configuration.system, domain: domain,
                   sendToSentryIfPossible: sendToSentryIfPossible)
    }

    // the info logs are not sent to sentry by default
    public static func info(_ message: String, domain: LogDomain, sendToSentryIfPossible: Bool = false) {
        logger.log(.info, message: message, system: configuration.system, domain: domain,
                   sendToSentryIfPossible: sendToSentryIfPossible)
    }

    // the warning logs are not sent to sentry by default
    public static func warning(_ message: String, domain: LogDomain, sendToSentryIfPossible: Bool = false) {
        logger.log(.warning, message: message, system: configuration.system, domain: domain,
                   sendToSentryIfPossible: sendToSentryIfPossible)
    }

    // the errors are sent to sentry by default
    public static func error(_ message: String, domain: LogDomain, sendToSentryIfPossible: Bool = true) {
        logger.log(.error, message: message, system: configuration.system, domain: domain,
                   sendToSentryIfPossible: sendToSentryIfPossible)
    }

    // the errors are sent to sentry by default
    public static func error<E: Error>(_ error: E, domain: LogDomain, sendToSentryIfPossible: Bool = true) {
        if let errorWithBreadcrumbs = error as? ErrorWithDetailedMessage {
            Self.error(errorWithBreadcrumbs.detailedMessage, domain: domain,
                       sendToSentryIfPossible: sendToSentryIfPossible)
        } else {
            logger.log(error as NSError, system: configuration.system, domain: domain,
                       sendToSentryIfPossible: sendToSentryIfPossible)
        }
    }

    /// Originated from PDClient
    public static func deserializationErrors(_ error: NSError) {
        guard error is DecodingError || error.underlyingErrors.contains(where: { $0 is DecodingError }) else { return }
        Log.error("🧨 Failed to deserialize response: \(error)", domain: .networking)
        if Constants.buildType.isQaOrBelow {
            assertionFailure("🧨 Failed to deserialize response: \(error)")
        }
    }

    public static func fireWarning(error: NSError) {
        guard Constants.buildType.isQaOrBelow else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "❌ \((error as NSError).code): \((error as NSError).domain)"
        content.subtitle = (error as NSError).localizedFailureReason ?? ""
        content.body = error.localizedDescription

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public static func logInfoAndNotify(title: String, message: String = "") {
        guard Constants.buildType.isQaOrBelow else { return }

        Log.info(title + " " + message, domain: .application)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
