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

public protocol UploadSpeedMetricResource {
    /// - Parameters:
    ///   - speed: is in KiB/s
    ///   - pipeline: pipeline responsible for the metric
    func sendMetric(speed: Int, isBackground: Bool, pipeline: DriveObservabilityPipeline)
}

public final class ObservabilityUploadSpeedMetricResource: UploadSpeedMetricResource {
    public func sendMetric(speed: Int, isBackground: Bool, pipeline: DriveObservabilityPipeline) {
        Log.debug("Sending upload speed metric: \(speed) KiBps", domain: .metrics)

        let context: DriveObservabilityUploadSpeedEventLabels.Context = isBackground ? .background : .foreground
        let labels = DriveObservabilityUploadSpeedEventLabels(context: context, pipeline: pipeline)
        let event = ObservabilityEvent(name: "drive_upload_speed_histogram", value: speed, labels: labels)
        ObservabilityEnv.report(event)
    }

    public init() {}
}
