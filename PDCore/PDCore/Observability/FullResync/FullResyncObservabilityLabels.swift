// Copyright (c) 2025 Proton AG
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
import ProtonCoreObservability

// Names omit the `_v1` suffix — it comes from `version: .v1`. Raw values match the schema registry.

public enum ScanEngineVersion: String, Encodable, Equatable {
    case v1
    case v2
}

// See mac_drive_full_resync_success_rate_total_v1.schema.json
public enum DriveFullResyncResult: String, Encodable, Equatable {
    case succeeded
    case failed
    case cancelled
}

public enum DriveFullResyncUserAction: String, Encodable, Equatable {
    case firstTry = "first_try"
    case retry
    case pauseResume = "pause_resume"
}

public enum DriveFullResyncStep: String, Encodable, Equatable {
    case nodesDiscovery = "nodes_discovery"
    case metadataFetch = "metadata_fetch"
    case statePropagation = "state_propagation"
}

// See mac_drive_full_resync_errors_total_v1.schema.json
public enum DriveFullResyncErrorType: String, Encodable, Equatable {
    case fourxx = "4xx"
    case fivexx = "5xx"
    case network
    case coreData = "core_data"
    case dbFiles = "db_files"
    case signaling
    case enumeration
    case unknown
}

// See mac_drive_full_resync_time_histogram_v1.schema.json
public enum DriveFullResyncTimeResult: String, Encodable, Equatable {
    case completed
    case aborted
}

public enum DriveFullResyncSize: String, Encodable, Equatable {
    case upTo10k = "up_to_10k"
    case tenK100k = "10k_100k"
    case hundredK1000k = "100k_1000k"
    case moreThan1000k = "more_than_1000k"
}

public struct DriveFullResyncResultLabels: Encodable, Equatable {
    let result: DriveFullResyncResult
    let userAction: DriveFullResyncUserAction
    let engine: ScanEngineVersion
    let step: DriveFullResyncStep

    enum CodingKeys: String, CodingKey {
        case result
        case userAction = "user_action"
        case engine
        case step
    }
}

public struct DriveFullResyncErrorLabels: Encodable, Equatable {
    let type: DriveFullResyncErrorType
    let engine: ScanEngineVersion
}

public struct DriveFullResyncTimeLabels: Encodable, Equatable {
    let result: DriveFullResyncTimeResult
    let size: DriveFullResyncSize
    let engine: ScanEngineVersion
}

public struct DriveFullResyncSpeedLabels: Encodable, Equatable {
    let step: DriveFullResyncStep
    let engine: ScanEngineVersion
}

public extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveFullResyncResultLabels> {
    // step is only metadata_fetch or state_propagation — a resync never stops during discovery.
    static func fullResyncSuccessRateEvent(result: DriveFullResyncResult, userAction: DriveFullResyncUserAction, engine: ScanEngineVersion, step: DriveFullResyncStep) -> Self {
        .init(name: "mac_drive_full_resync_success_rate_total", labels: .init(result: result, userAction: userAction, engine: engine, step: step))
    }
}

public extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveFullResyncErrorLabels> {
    static func fullResyncErrorEvent(type: DriveFullResyncErrorType, engine: ScanEngineVersion) -> Self {
        .init(name: "mac_drive_full_resync_errors_total", labels: .init(type: type, engine: engine))
    }
}

public extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveFullResyncTimeLabels> {
    static func fullResyncTimeEvent(minutes: Int, result: DriveFullResyncTimeResult, size: DriveFullResyncSize, engine: ScanEngineVersion) -> Self {
        .init(name: "mac_drive_full_resync_time_histogram", value: minutes, labels: .init(result: result, size: size, engine: engine))
    }
}

public extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveFullResyncSpeedLabels> {
    static func fullResyncSpeedEvent(step: DriveFullResyncStep, engine: ScanEngineVersion, nodesPerSecond: Int) -> Self {
        .init(name: "mac_drive_full_resync_speed_histogram", value: nodesPerSecond, labels: .init(step: step, engine: engine))
    }
}
