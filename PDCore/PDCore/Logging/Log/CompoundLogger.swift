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

/// Manages a collection of loggers and forwards log events to all of them.
public final class CompoundLogger: StructuredLogger {

    private var loggers: [any LoggerProtocol]

    public init(loggers: [any LoggerProtocol]) {
        self.loggers = loggers
    }

    public func log(_ logEntry: StructuredLogEntry) {
        loggers.forEach {
            if let structuredLogger = $0 as? any StructuredLogger {
                structuredLogger.log(logEntry)
            } else {
                $0.log(
                    logEntry.level,
                    message: logEntry.formattedMessage,
                    system: logEntry.system,
                    domain: logEntry.domain,
                    context: logEntry.context,
                    sendToSentryIfPossible: logEntry.sendToSentryIfPossible,
                    file: logEntry.file,
                    function: logEntry.function,
                    line: logEntry.line
                )
            }
        }
    }

    public func removeAll(where shouldBeRemoved: (LoggerProtocol) -> Bool) {
        loggers.removeAll(where: shouldBeRemoved)
    }

    public func append(logger: any LoggerProtocol) {
        loggers.append(logger)
    }
}
