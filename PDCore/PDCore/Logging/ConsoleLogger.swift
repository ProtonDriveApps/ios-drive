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
import UserNotifications
import os.log

public protocol PDLogger {
    func log(_ error: Error, osLogType: LogObject.Type)
    func log(_ event: String, osLogType: LogObject.Type)
}

public extension PDLogger {
    func log(_ error: Error, osLogType: LogObject.Type) { }
    func log(_ event: String, osLogType: LogObject.Type) { }
}

/*Use
 let logger: PDLogger? = ConsoleLogger.shared
 let url = URL(string: "http://some/url.com")!
 logger?.log("Hello World! - Went to URL: \(url)", osLogType: LogSubsystem.self)

 e.g.:

 final class Uploader {
    let dependency1: Dependency1
    let logger: PDLogger?

    init(dependency1: Dependency1, logger: Logger? = ConsoleLogger.shared) {
        ...
    }

    func foo() {
        let url = URL(string: "http://some/url.com")!
 
        logger?.log("Hello World! - Went to URL: \(url)", osLogType: LogSubsystem.self)
        dependency1.doSomethingImportant(with: url)
    }
 }
 */

@available(*, deprecated, message: "Use Log instead.")
public final class ConsoleLogger: PDLogger {
    public static let shared = ConsoleLogger()

    private init?() { }

    public func fireWarning(error: Error) {
        #if HAS_QA_FEATURES
        let content = UNMutableNotificationContent()
        content.title = "❌ \((error as NSError).code): \((error as NSError).domain)"
        content.subtitle = (error as NSError).localizedFailureReason ?? ""
        content.body = error.localizedDescription
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    public func fireWarning(event: String) {
        #if HAS_QA_FEATURES
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Notification event"
        content.body = event

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    public func logAndNotify(title: String, message: String, osLogType: LogObject.Type) {
        #if HAS_QA_FEATURES
        os_log("%{public}@", log: osLogType.osLog, type: .default, title + " " + message)
        #endif

        #if SUPPORTS_BACKGROUND_UPLOADS
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }
}

struct SignatureError: LocalizedError, Loggable {
    static var osLog: OSLog = OSLog(subsystem: "ch.protondrive", category: "Signature Verification Error")
    let error: Error
    let description: String
    var context: Context
    let method: StaticString

    init(_ error: Error, _ context: Context, description: String? = nil, method: StaticString = #function) {
        self.error = error
        self.context = context
        self.method = method
        self.description = (description == nil) ? "" : "\n\(description!)"
    }

    var errorDescription: String? {
        "\(context) - \(method) - Signature Error ⚠️" + "\n\(error.localizedDescription)" + description
    }
}

struct DecryptionError: LocalizedError, Loggable {
    static var osLog: OSLog = OSLog(subsystem: "ch.protondrive", category: "Decryption Error")
    let error: Error
    let description: String
    let context: Context
    let method: StaticString

    init(_ error: Error, _ context: Context, description: String? = nil, method: StaticString = #function)  {
        self.error = error
        self.context = context
        self.method = method
        self.description = (description == nil) ? "" : "\n\(description!)"
    }

    var errorDescription: String? {
        "\(context) - \(method) - Decryption Error ❌" + "\n\(error.localizedDescription)" + description
    }
}

public struct DriveError: LocalizedError, CustomDebugStringConvertible {
    public let message: String
    public let file: String
    public let line: String

    public init(_ message: String, file: String = #filePath, line: Int = #line) {
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.line = String(line)
    }

    public init(_ error: Error, file: String = #filePath, line: Int = #line) {
        self.init(error.localizedDescription, file: file, line: line)
    }

    public init(withDomainAndCode error: Error, message: String? = nil, file: String = #filePath, line: Int = #line) {
        let error = error as NSError
        let message = "\(error.domain) \(error.code), message: \(message ?? "empty")"
        self.init(message, file: file, line: line)
    }

    public var errorDescription: String? {
        #if HAS_QA_FEATURES
            return debugDescription
        #elseif HAS_BETA_FEATURES
            return debugDescription
        #else
            return message
        #endif
    }

    public var debugDescription: String {
        message + "\(file) - \(line)"
    }
}

struct DriveSignatureError: Error {
    let method: String

    init(_ method: String = #function) {
        self.method = method
    }
}

/// Providing similar functionality as `DriveError` while keeping the original `domain` and `code`
/// `message` should not contain sensitive data.
public class DomainCodeError: NSError {
    public init(error: NSError, message: String? = nil, file: String = #filePath, line: Int = #line) {
        let message = "\(error.domain) \(error.code), message: \(message ?? "empty")"
        super.init(domain: error.domain, code: error.code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Error structure just for holding displayable error message.
/// Helpful for passing error messages to the UI.
public struct PlainMessageError: LocalizedError {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}
