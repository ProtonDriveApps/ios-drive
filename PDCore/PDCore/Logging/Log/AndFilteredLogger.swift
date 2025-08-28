// Copyright (c) 2024 Proton AG
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

/// Filters logs based on logLevel AND domain.
public final class AndFilteredLogger: LoggerProtocol {
    private let logger: LoggerProtocol
    private let domains: Set<LogDomain>
    private let levels: Set<LogLevel>

    public init(logger: LoggerProtocol, domains: Set<LogDomain>, levels: Set<LogLevel>) {
        self.logger = logger
        self.domains = domains
        self.levels = levels
    }

    // swiftlint:disable:next function_parameter_count
    public func log(_ level: LogLevel, message: String, system: LogSystem, domain: LogDomain, context: LogContext?, sendToSentryIfPossible: Bool, file: String, function: String, line: Int) {
        guard isValid(level: level, domain: domain) else {
            return
        }

        logger.log(level, message: message, system: system, domain: domain, context: context, sendToSentryIfPossible: sendToSentryIfPossible, file: file, function: function, line: line)
    }

    private func isValid(level: LogLevel, domain: LogDomain) -> Bool {
        return levels.contains(level) && domains.contains(domain)
    }
}
