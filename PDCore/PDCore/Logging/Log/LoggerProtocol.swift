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

public protocol LoggerProtocol {
    // swiftlint:disable:next function_parameter_count
    func log(
        _ level: LogLevel,
        message: String,
        system: LogSystem,
        domain: LogDomain,
        context: LogContext?,
        sendToSentryIfPossible: Bool,
        file: String,
        function: String,
        line: Int
    )
}

extension LoggerProtocol {
    func log(
        _ level: LogLevel,
        message: String,
        system: LogSystem,
        domain: LogDomain,
        sendToSentryIfPossible: Bool,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level,
            message: message,
            system: system,
            domain: domain,
            context: nil,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line
        )
    }
}

public protocol StructuredLogger: LoggerProtocol {
    func log(_ logEntry: StructuredLogEntry)
}

extension StructuredLogger {
    // swiftlint:disable:next function_parameter_count
    public func log(
        _ level: LogLevel,
        message: String,
        system: LogSystem,
        domain: LogDomain,
        context: LogContext?, 
        sendToSentryIfPossible: Bool, 
        file: String,
        function: String,
        line: Int) {
        log(
            StructuredLogEntry(
                level: level,
                message: message,
                timestamp: Log.formattedTime,
                threadNumber: Thread.current.number.description,
                system: system,
                domain: domain,
                context: context,
                sendToSentryIfPossible: sendToSentryIfPossible,
                file: URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent,
                function: function,
                line: line
            )
        )
    }
}

public struct StructuredLogEntry {
    let level: LogLevel
    let message: String
    let timestamp: String
    let threadNumber: String
    let system: LogSystem
    let domain: LogDomain
    let context: LogContext?
    let sendToSentryIfPossible: Bool
    let file: String
    let function: String
    let line: Int

    var formattedMessage: String {
        let result = "[\(threadNumber)] \(file).\(function):\(line) \(message)"
        return result
    }
}

/// Any information logged together with a message and/or error.
public struct LogContext: CustomDebugStringConvertible {
    public var context = [String: String]()

    public init(_ string: String? = nil) {
        if let string {
            self.context["contextString"] = string
        }
    }

    public subscript(key: String) -> String? {
        get {
            context[key]
        }
        set(newValue) {
            context[key] = newValue
        }
    }

    public var debugDescription: String {
        guard !context.isEmpty else {
            return ""
        }
        return String(context.reduce("") { $0 + "\($1.key): \($1.value), " }.dropLast(2))
    }
}
