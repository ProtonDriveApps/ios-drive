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
import os.log

/// Writes logs to the Xcode debugging console and Console.app.
/// NOTE: Debug and Info levels are not shown in Console.app by default - select "Actions -> Include Debug Messages" or "Actions -> Include Info Messages" to view them.
/// Also, you can right-click the column titles in Console.app and select "Category" to see log domains.
public final class DebugLogger: LoggerProtocol {
    public init() {}

    // DebugLogger never sends to Sentry, regardless of the parameter's value
    // swiftlint:disable:next function_parameter_count
    public func log(_ level: LogLevel, message: String, system: LogSystem, domain: LogDomain, context: LogContext?, sendToSentryIfPossible _: Bool, file: String, function: String, line: Int) {
        let log = OSLog(subsystem: system.name, category: domain.name)
        let type = makeType(from: level)
        var message = message
        if let contextString = context?.debugDescription, !contextString.isEmpty {
            message += "; \(contextString)"
        }
        os_log("%{public}@", log: log, type: type, "\(message)")
    }

    private func makeType(from level: LogLevel) -> OSLogType {
        switch level {
        case .error:
            return .fault
        case .warning:
            return .error
        case .info:
            return .info
        case .debug:
            return .debug
        case .trace:
            return .debug
        }
    }
}
