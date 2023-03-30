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

public protocol Logger {
    func log(_ error: Error, osLogType: LogObject.Type)
    func log(_ event: String, osLogType: LogObject.Type)
}

public extension Logger {
    func log(_ error: Error, osLogType: LogObject.Type) { }
    func log(_ event: String, osLogType: LogObject.Type) { }
}

/*Use
 let logger: Logger? = ConsoleLogger.shared
 let url = URL(string: "http://some/url.com")!
 logger?.log("Hello World! - Went to URL: \(url)", osLogType: LogSubsystem.self)

 e.g.:

 final class Uploader {
    let dependency1: Dependency1
    let logger: Logger?

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
public final class ConsoleLogger: Logger {
    public static let shared = ConsoleLogger()
    
    @discardableResult
    public static func reportMemory() -> Float {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let usedMb = Float(taskInfo.phys_footprint) / 1048576.0
        let totalMb = Float(ProcessInfo.processInfo.physicalMemory) / 1048576.0
        result != KERN_SUCCESS ? print("Memory used: ? of \(totalMb)") : print("Memory used: \(usedMb) of \(totalMb)")
        
        return usedMb
    }
    
    private static var lastReportedMemoryUse: Float = reportMemory()
    public static func reportMemoryDiff(token: String, file: String = #file, line: Int = #line) {
        let file = URL(fileURLWithPath: file).lastPathComponent
        print("[\(token) | \(file):\(line)]\tMemory allocated: \(reportMemory() - lastReportedMemoryUse)")
        lastReportedMemoryUse = ConsoleLogger.reportMemory()
    }

    private init?() { }

    private func log(_ message: String, level: OSLogType, osLog: OSLog) {
        #if DEBUG
        os_log("%{public}@", log: osLog, type: level, message)
        #endif
    }

    public func log(_ error: Error, osLogType: LogObject.Type) {
        #if DEBUG
        // development builds should not send reports to Sentry
        ConsoleLogger.shared?.log(String(describing: error), level: .error, osLog: osLogType.osLog)
        #else
        SentryClient.shared.recordError(error as NSError)
        #endif
    }
    
    public func logDeserializationErrors(_ error: NSError) {
        guard error is DecodingError || error.underlyingErrors.contains(where: { $0 is DecodingError }) else { return }
        
        #if DEBUG
        assertionFailure("🧨 Failed to deserialize response: \(error)")
        #else
        SentryClient.shared.recordError(error)
        #endif
    }

    public func log<T>(_ error: T) where T: Error, T: Loggable {
        log(error, osLogType: T.self)
    }

    public func log(_ event: String, osLogType: LogObject.Type) {
        ConsoleLogger.shared?.log(event, level: .default, osLog: osLogType.osLog)
    }

    public func fireWarning(error: Error) {
        #if DEBUG
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
        #if DEBUG
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Notification event"
        content.body = event

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    public func logAndNotify(title: String, message: String, osLogType: LogObject.Type) {
        #if DEBUG
        log(title + " " + message, osLogType: osLogType)
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
    var context: Context
    let method: StaticString

    init(_ error: Error, _ context: Context, method: StaticString = #function) {
        self.error = error
        self.context = context
        self.method = method
    }

    var errorDescription: String? {
        "\(context) - \(method) - Signature Error ⚠️ \n" + error.messageForTheUser
    }
}

struct DecryptionError: LocalizedError, Loggable {
    static var osLog: OSLog = OSLog(subsystem: "ch.protondrive", category: "Decryption Error")
    let error: Error
    let context: Context
    let method: StaticString

    init(_ error: Error, _ context: Context, method: StaticString = #function)  {
        self.error = error
        self.context = context
        self.method = method
    }

    var errorDescription: String? {
        "\(context) - \(method) - Decryption Error ❌ \n" + error.messageForTheUser
    }
}

public struct DriveError: LocalizedError, Loggable {
    public static var osLog: OSLog = OSLog(subsystem: "ch.protondrive", category: "Generic Drive Error")
    public let error: Error
    public let context: String
    public let method: String

    public init(_ error: Error, _ context: Context, method: String = #function) {
        self.error = error
        self.context = context
        self.method = method
    }

    public var errorDescription: String? {
        "\(context) - \(method) - Generic Drive Error \n" + error.messageForTheUser
    }
}

struct DriveSignatureError: Error {
    let method: String

    init(_ method: String = #function) {
        self.method = method
    }
}
