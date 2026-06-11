// Copyright (c) 2026 Proton AG
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

public protocol ObservabilityEventWriting {
    func write(_ entry: ObservabilityEventEntry)
}

public final class ObservabilityEventFileWriter: ObservabilityEventWriting {
    public static let shared: ObservabilityEventWriting = ObservabilityEventFileWriter()

    private let logger: FileWritingLogger
    private let queue: DispatchQueue
    private let encoder: JSONEncoder

    public init(logger: FileWritingLogger) {
        self.logger = logger
        self.queue = DispatchQueue(label: "ch.protonmail.drive.observability-events-writer", qos: .utility)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    private convenience init() {
        let eventsDirectory = PDFileManager.observabilityEventsDirectory

        let rotator = CleaningFileLogRotatorDecorator(
            archiveDirectory: eventsDirectory,
            maximumArchiveSize: 50_000_000,
            maxLogAgeDays: 7,
            rotator: FileRenamingFileRotatorDecorator(
                rotationDirectory: eventsDirectory,
                rotator: BlankFileRotator()
            )
        )

        let logger = FileWritingLogger(
            logSystem: .observabilityEvents,
            maxFileSize: 10_000_000,
            rotator: rotator,
            workingDirectory: eventsDirectory
        )

        self.init(logger: logger)
    }

    public func write(_ entry: ObservabilityEventEntry) {
        queue.async { [weak self] in
            self?.performWrite(entry)
        }
    }

    func writeSync(_ entry: ObservabilityEventEntry) {
        queue.sync {
            performWrite(entry)
        }
    }

    private func performWrite(_ entry: ObservabilityEventEntry) {
        let message = formatEntry(entry)
        logger.log(
            .info,
            message: message,
            system: .observabilityEvents,
            domain: .telemetry,
            sendToSentryIfPossible: false
        )
    }

    private func formatEntry(_ entry: ObservabilityEventEntry) -> String {
        guard let data = try? encoder.encode(entry),
              let json = String(data: data, encoding: .utf8) else {
            return "\(entry.source) | \(entry.group) | \(entry.event)"
        }
        return json
    }
}
