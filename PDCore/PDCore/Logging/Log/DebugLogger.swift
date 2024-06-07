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

public final class DebugLogger: LoggerProtocol {
    public init() {}

    // DebugLogger never sends to Sentry, regardless of the parameter's value
    public func log(_ level: LogLevel, message: String, system: LogSystem, domain: LogDomain, sendToSentryIfPossible _: Bool) {
        let log = OSLog(subsystem: system.name, category: domain.name)
        let type = makeType(from: level)
        os_log("%{public}@", log: log, type: type, message)
    }

    // DebugLogger never sends to Sentry, regardless of the parameter's value
    public func log(_ error: NSError, system: LogSystem, domain: LogDomain, sendToSentryIfPossible _: Bool) {
        let message = error.localizedDescription
        log(.error, message: message, system: system, domain: domain, sendToSentryIfPossible: false)
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
        }
    }
}
