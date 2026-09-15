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

public protocol FullResyncMetricsReporting: Sendable {
    func reportResult(result: DriveFullResyncResult, userAction: DriveFullResyncUserAction, engine: ScanEngineVersion, step: DriveFullResyncStep)
    func reportError(type: DriveFullResyncErrorType, engine: ScanEngineVersion)
    func reportTime(minutes: Int, result: DriveFullResyncTimeResult, size: DriveFullResyncSize, engine: ScanEngineVersion)
    func reportSpeed(step: DriveFullResyncStep, engine: ScanEngineVersion, nodeCount: Int, elapsed: TimeInterval)
}

public final class FullResyncObservabilityMonitor: FullResyncMetricsReporting {
    private let environment: ObservabilityEnvProtocol.Type

    public init(environment: ObservabilityEnvProtocol.Type = ObservabilityEnv.self) {
        self.environment = environment
    }

    public func reportResult(result: DriveFullResyncResult, userAction: DriveFullResyncUserAction, engine: ScanEngineVersion, step: DriveFullResyncStep) {
        let event = ObservabilityEvent.fullResyncSuccessRateEvent(result: result, userAction: userAction, engine: engine, step: step)
        environment.report(event)
    }

    public func reportError(type: DriveFullResyncErrorType, engine: ScanEngineVersion) {
        let event = ObservabilityEvent.fullResyncErrorEvent(type: type, engine: engine)
        environment.report(event)
    }

    public func reportTime(minutes: Int, result: DriveFullResyncTimeResult, size: DriveFullResyncSize, engine: ScanEngineVersion) {
        let event = ObservabilityEvent.fullResyncTimeEvent(minutes: minutes, result: result, size: size, engine: engine)
        environment.report(event)
    }

    public func reportSpeed(step: DriveFullResyncStep, engine: ScanEngineVersion, nodeCount: Int, elapsed: TimeInterval) {
        guard elapsed > 0, nodeCount > 0 else { return }
        // A tiny elapsed can push nodes/sec past Int's range (Int(_: Double) traps on overflow / non-finite);
        // map an out-of-range rate to the histogram's top bucket rather than dropping the sample.
        let rate = (Double(nodeCount) / elapsed).rounded()
        let nodesPerSecond = rate.isFinite ? Int(min(max(rate, 0), Double(Int32.max))) : Int(Int32.max)
        let event = ObservabilityEvent.fullResyncSpeedEvent(step: step, engine: engine, nodesPerSecond: nodesPerSecond)
        environment.report(event)
    }
}

public struct NoOpFullResyncMetricsReporting: FullResyncMetricsReporting {
    public init() {}
    public func reportResult(result: DriveFullResyncResult, userAction: DriveFullResyncUserAction, engine: ScanEngineVersion, step: DriveFullResyncStep) {}
    public func reportError(type: DriveFullResyncErrorType, engine: ScanEngineVersion) {}
    public func reportTime(minutes: Int, result: DriveFullResyncTimeResult, size: DriveFullResyncSize, engine: ScanEngineVersion) {}
    public func reportSpeed(step: DriveFullResyncStep, engine: ScanEngineVersion, nodeCount: Int, elapsed: TimeInterval) {}
}
