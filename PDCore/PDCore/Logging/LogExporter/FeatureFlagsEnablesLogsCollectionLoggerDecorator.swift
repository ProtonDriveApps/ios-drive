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
import Combine

// This class will stop keeping more logs to the log file if the user has disabled the log collection
// once the user logs out the previous logs will be deleted
public final class FeatureFlagsEnablesLogsCollectionLoggerDecorator: LoggerProtocol {
    private var cancellables = Set<AnyCancellable>()
    private var logCollectionDisabled: Bool

    private let decoratee: LoggerProtocol

    public init(decoratee: LoggerProtocol, store: LocalSettings) {
        self.decoratee = decoratee
        self.logCollectionDisabled = store.logCollectionDisabled

        store.publisher(for: \.logCollectionDisabled)
            .removeDuplicates()
            .receive(on: DispatchQueue.logsQueue)
            .sink { [weak self] in
                guard let self = self else { return }
                self.logCollectionDisabled = $0
            }
            .store(in: &cancellables)
    }

    // swiftlint:disable:next function_parameter_count
    public func log(_ level: LogLevel, message: String, system: LogSystem, domain: LogDomain, context: LogContext?, sendToSentryIfPossible: Bool, file: String, function: String, line: Int) {
        guard !(logCollectionDisabled == true) else { return }
        decoratee.log(level, message: message, system: system, domain: domain, context: context, sendToSentryIfPossible: sendToSentryIfPossible, file: file, function: function, line: line)
    }
}
