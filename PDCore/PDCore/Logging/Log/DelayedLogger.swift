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

/// Keeps logs in memory until logger is set up.
public final actor DelayedLogger: StructuredLogger {

    private var delayedLogs = [StructuredLogEntry]()

    nonisolated public func log(_ logEntry: StructuredLogEntry) {
        Task {
            await append(logEntry)
        }
    }

    nonisolated public func drain(into logger: StructuredLogger) {
        Task {
            await delayedLogs.forEach {
                logger.log($0)
            }
            await removeAll()
        }
    }

    private func append(_ logEntry: StructuredLogEntry) {
        delayedLogs.append(logEntry)
    }

    private func removeAll() {
        delayedLogs.removeAll()
    }

    deinit {
        // If the app is terminating before the logger was configured,
        // dump its contents so we can know what happened.
        let log = CompoundLogger(loggers: [DebugLogger()])
        delayedLogs.forEach {
            log.log($0)
        }
    }
}
