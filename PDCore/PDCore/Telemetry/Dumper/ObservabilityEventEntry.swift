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

/// Represents a telemetry/observability event entry written to disk.
/// Used for QA debugging to capture all metrics events sent by the app and SDK.
public struct ObservabilityEventEntry: Encodable {
    /// ISO8601 formatted timestamp when the event was captured
    public let timestamp: String
    /// Source of the event: "app", "sdk", or "observability"
    public let source: String
    /// Measurement group (e.g., "drive.any.photos", "drive_sdk_upload_success_rate_total")
    public let group: String
    /// Event name (e.g., "backup.stopped", "v1" for observability version)
    public let event: String
    /// Numeric values associated with the event
    public let values: [String: Double]
    /// String dimensions/metadata associated with the event
    public let dimensions: [String: String]

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Creates an entry with automatic timestamp generation.
    /// - Parameters:
    ///   - source: Source of the event ("app", "sdk", or "observability")
    ///   - group: Measurement group name
    ///   - event: Event name
    ///   - values: Numeric values (defaults to empty)
    ///   - dimensions: String dimensions (defaults to empty)
    ///   - date: Date for timestamp generation (defaults to current date)
    public init(
        source: String,
        group: String,
        event: String,
        values: [String: Double] = [:],
        dimensions: [String: String] = [:],
        date: Date = Date()
    ) {
        self.timestamp = Self.timestampFormatter.string(from: date)
        self.source = source
        self.group = group
        self.event = event
        self.values = values
        self.dimensions = dimensions
    }
}
