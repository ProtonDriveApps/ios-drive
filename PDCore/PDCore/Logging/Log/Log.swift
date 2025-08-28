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

    public init(name: String) {
        self.name = name
    }

    public static let albums = LogDomain(name: "albums")
    public static let application = LogDomain(name: "application")
    public static let applicationBootstrap = LogDomain(name: "applicationBootstrap")
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
    public static let metadata = LogDomain(name: "metadata")
    public static let updater = LogDomain(name: "uploader")
    public static let enumerating = LogDomain(name: "enumerating")
    public static let sessionManagement = LogDomain(name: "sessionManagement")
    public static let sharing = LogDomain(name: "sharing")
    public static let offlineAvailable = LogDomain(name: "offlineAvailable")
    public static let diagnostics = LogDomain(name: "diagnostics")
    public static let logs = LogDomain(name: "logs")
    public static let protonDocs = LogDomain(name: "protonDocs")
    public static let testRunner = LogDomain(name: "testRunner")
    public static let contact = LogDomain(name: "contact")
    public static let ddk = LogDomain(name: "ddk")
    public static let restricted = LogDomain(name: "restricted")
    public static let computers = LogDomain(name: "computers")
    public static let scenes = LogDomain(name: "scenes")
    public static let userAction = LogDomain(name: "userAction")
    public static let ui = LogDomain(name: "ui")
    public static let photosTagMigration = LogDomain(name: "photosTagMigration")
    public static let userSettings = LogDomain(name: "userSettings")
    public static let exifBackfill = LogDomain(name: "exifBackfill")

    public static let iOSDomains: Set<LogDomain> = [
        .applicationBootstrap,
        .application,
        .encryption,
        .events,
        .networking,
        .uploader,
        .backgroundTask,
        .photosProcessing,
        .photosUI,
        .clientNetworking,
        .trustKit,
        .telemetry,
        .featureFlags,
        .updater,
        .sessionManagement,
        .sharing,
        .offlineAvailable,
        .diagnostics,
        .logs,
        .protonDocs,
        .storage,
        .metadata,
        .computers,
        .scenes,
        .albums,
        .userAction,
        .ui,
        .restricted,
        .photosTagMigration,
        .userSettings,
        .exifBackfill
    ]

    public static func macOSDomains(appending: Set<LogDomain>, subtracting: Set<LogDomain>) -> Set<LogDomain> {
        let domains = Set(
            [
                .application,
                .diagnostics,
                .downloader,
                .encryption,
                .events,
                .fileManager,
                .fileProvider,
                .enumerating,
                .networking,
                .protonDocs,
                .sessionManagement,
                .storage,
                .syncing,
                .uploader,
                .testRunner,
                .logs
            ])
            .union(appending)
            .subtracting(subtracting)

        return domains
    }
}

public enum LogLevel: String, CaseIterable {
    case error
    case warning
    case info
    case debug
    case trace

    var description: String {
        self.rawValue.uppercased()
    }
}

public class Log {
    public static var logger: LoggerProtocol = DelayedLogger()
    public static var logSystem: LogSystem = .default

    public static var enableTraces = true

    public static var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date.now)
    }

    // debug logs are not sent to sentry by default
    public static func debug(
        _ message: String,
        domain: LogDomain,
        sendToSentryIfPossible: Bool = false,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        logger.log(
            .debug,
            message: message,
            system: logSystem,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file, 
            function: function,
            line: line
        )
    }

    // info logs are not sent to sentry by default
    public static func info(
        _ message: String,
        domain: LogDomain,
        sendToSentryIfPossible: Bool = false,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        logger.log(
            .info,
            message: message,
            system: logSystem,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line
        )
    }

    // warning logs are not sent to sentry by default
    public static func warning(
        _ message: String,
        domain: LogDomain,
        sendToSentryIfPossible: Bool = false,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        logger.log(
            .warning,
            message: message,
            system: logSystem, domain: domain,
            context: nil,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line
        )
    }

    /// - Parameters:
    ///   - message:can be nil if `error` is always the same. If `error` can vary, provide a static `message` to describe the operation that errored
    ///   - error:can be nil if `message` contains everything we have/need to know
    ///   - sendToSentryIfPossible:errors are sent to sentry by default
    ///   The original error will also be logged locally for debugging purposes.
    public static func error(
        _ message: String? = nil,
        error: Error? = nil,
        domain: LogDomain,
        context: LogContext? = nil,
        sendToSentryIfPossible: Bool = true,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        assert(message != nil || error != nil)

        var logContext = context ?? LogContext()

        if sendToSentryIfPossible {
            let serializer = SanitizedErrorSerializer()
            if let error {
                logContext.context["serializedError"] = serializer.serialize(error: error)
            }
        }

        logger.log(
            .error,
            message: message ?? "",
            system: logSystem,
            domain: domain,
            context: logContext,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line
        )
    }

    /// - Parameters:
    ///   - sendToSentryIfPossible: the errors are sent to sentry by default
    ///   - shouldRedact: The received error will be converted to a DriveError to redact any potential privacy data before sending it to Sentry.
    ///   The original error will also be logged locally for debugging purposes.
    @available(*, deprecated, message: "Use error(_ message: String?, error: Error?, ...) instead")
    public static func error<E: Error>(
        _ error: E,
        domain: LogDomain,
        sendToSentryIfPossible: Bool = true,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        self.error(
            error.localizedDescription,
            error: error,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line
        )
    }

    @available(*, deprecated, message: "Use error(_ message: String?, error: Error?, ...) instead")
    public static func error(
        _ message: String,
        domain: LogDomain,
        sendToSentryIfPossible: Bool = true,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        self.error(
            message,
            error: nil,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line
        )
    }

    // Automatically logs call site information of wherever it is called from.
    public static func trace(
        _ message: @autoclosure () -> String = "",
        file: String = #filePath,
        function: String = #function,
        line: Int = #line,
        domain: LogDomain = .diagnostics
    ) {
        guard enableTraces else {
            return
        }

        logger.log(
            .trace,
            message: message(),
            system: logSystem,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: false,
            file: file,
            function: function,
            line: line
        )
    }

    /// Originated from PDClient
    public static func deserializationErrors(_ error: NSError) {
        guard error is DecodingError || error.underlyingErrors.contains(where: { $0 is DecodingError }) else { return }
        Log.error("🧨 Failed to deserialize response", error: error, domain: .networking)
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

extension Thread {
    var number: String {
        Thread.current.description.range(of: "(?<=number = )\\d+", options: .regularExpression).map { String(Thread.current.description[$0]) } ?? ""
    }
}

public extension String {
    /// Removes username from a filepath
    var removingUserName: String {
        replacing(#/\/Users\/.*\//#, with: "/Users/username/")
    }
    
    var removingDotNetNoise: String {
        replacing("PublicKeyToken=null", with: "")
            .replacing(#/Version=\d+\.\d+\.\d+\.\d+/#, with: "")
    }
}
