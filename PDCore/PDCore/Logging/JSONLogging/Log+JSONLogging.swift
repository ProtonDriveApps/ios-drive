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

extension Log {
    /// Logs a FileOperationEvent to JSONLogger
    public static func event(
        _ event: FileOperationEvent,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        self.logEvent(event, file: file, function: function, line: line)
    }
}

extension Log {
    /// Logs a UI update to JSONLogger
    public static func uiEvent(
        _ params: [String],
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        let event = UILoggableEvent.uiUpdate(params)
        self.logEvent(event, file: file, function: function, line: line)
    }
    
    /// Logs a user action to JSONLogger
    public static func userAction(
        _ params: [String: Encodable] = [:],
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        let event = UILoggableEvent.userAction(params.mapValues { AnyEncodable($0) })
        self.logEvent(event, file: file, function: function, line: line)
    }
    
    /// Logs system metrics
    public static func systemMetrics(
        _ metrics: SystemMetricsSnapshot,
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) {
        self.logEvent(metrics, file: file, function: function, line: line)
    }
}
