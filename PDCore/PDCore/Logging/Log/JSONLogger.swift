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

/// Defines the properties an object needs to have in order to be loggable by JSONLogger
public protocol JSONLoggable: Encodable {
    var eventName: String { get }
    var logLevel: LogLevel { get }
    var domain: LogDomain { get }
}

extension LogContext {
    private static let key: String = "_jsonPayload"

    init(jsonPayload: JSONLoggable) {
        self[Self.key] = jsonPayload
    }

    var jsonPayload: JSONLoggable? {
        get {
            self.context[Self.key] as? JSONLoggable
        }
        set {
            self.context[Self.key] = newValue
        }
    }

    public var hasJSONPayload: Bool {
        jsonPayload != nil
    }
}

/// Writes logs as JSONL.
public class JSONLogger: FileLogger {

    private let startTime: Date

    public override init(
        process: FileLog,
        subdirectory: String? = nil,
        oneFilePerRun: Bool,
        compressedLogsDisabled: @escaping () -> Bool
    ) {
        self.startTime = Date.now
        super.init(
            process: process,
            oneFilePerRun: oneFilePerRun,
            compressedLogsDisabled: compressedLogsDisabled
        )
    }

    public func log(
        _ level: LogLevel,
        system: LogSystem,
        domain: LogDomain,
        context: LogContext?,
        sendToSentryIfPossible: Bool,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard let context, isValid(logContext: context) else {
            return
        }

        super.log(
            level,
            message: "",
            system: system,
            domain: domain,
            context: context,
            sendToSentryIfPossible: sendToSentryIfPossible,
            file: file,
            function: function,
            line: line)
    }

    /*
     -- Example query to read the values logged here using DuckDB:
     SELECT
       dt as date,
       sys as system,
       dom as domain,
       name,
       lvl as level,
       mode,
       payload -> '$.state' state,
       payload -> '$.itemID' itemID,
       payload -> '$.changedFields' changedFields,
       payload -> '$.stillPendingFields' pendingFields,
       payload -> '$.hasContents' hasContents,
       payload -> '$.options' opts,
       payload -> '$.error' err,
       payload -> '$.parentIDs' parentIDs,
       payload -> '$.version' versionID,
       payload -> '$.eventSource' eventSource,
       payload -> '$.containerType' containerType,
       payload,
       file,
       func as function,
       v as version,
       runID,
       uptime
     FROM
       read_json("~/Library/Group Containers/.../Logs/log-ProtonDrive*.jsonl.*.log")
     ORDER BY
       ts DESC
     */
    /// Combines all the data to write to the log into a JSON object.
    override func formatMessage(
        level: LogLevel,
        message: String,
        system: LogSystem,
        domain: LogDomain,
        context: LogContext?,
        sendToSentryIfPossible _: Bool,
        file: String,
        function: String,
        line: Int) -> String? {
            guard let jsonPayload = context?.jsonPayload else {
                return nil
            }
            let now = Date.now
            let data: [String: AnyEncodable] = [
                "ts": AnyEncodable(now.timeIntervalSince1970),
                "dt": AnyEncodable(now.description),
                "lvl": AnyEncodable(level.rawValue),
                "sys": AnyEncodable(system.suffix),
                "dom": AnyEncodable(domain.name),
                "file": AnyEncodable("\(file):\(line)"),
                "func": AnyEncodable(function),
                "thr": AnyEncodable(Thread.current.number.description),
                "v": AnyEncodable(Constants.clientVersion ?? "n/a"),
                "payload": AnyEncodable(jsonPayload),
                "name": AnyEncodable(jsonPayload.eventName),
                "runID": AnyEncodable(startTime.timeIntervalSince1970),
                "uptime": AnyEncodable(now.timeIntervalSince(startTime))
            ]

            return try? data.toJSON()
        }

    override var fileExtension: String {
        ".jsonl.log"
    }

    private func isValid(logContext: LogContext) -> Bool {
        return logContext.hasJSONPayload
    }
}

/// A type-erased Encodable to allow encoding heterogeneous values in containers
public struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    public init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

extension Encodable {
    /// Converts object to JSON string
    func toJSON(_ encoder: JSONEncoder = JSONEncoder()) throws -> String? {
        let encoder = encoder
        encoder.outputFormatting = []
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let result = String(data: data, encoding: .utf8)
        return result
    }
}

