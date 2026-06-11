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

protocol PerformancePreviewToThumbnailResource {
    /// - Parameters:
    ///   - duration in milliseconds
    func send(labels: PerformancePreviewToThumbnailLabels, duration: Measurement<UnitDuration>)
}

final class ObservabilityPerformancePreviewToThumbnailResource: PerformancePreviewToThumbnailResource {
    func send(labels: PerformancePreviewToThumbnailLabels, duration: Measurement<UnitDuration>) {
        Log.debug("Sending preview to thumbnail: \(labels.pageType), \(labels.fileType), \(labels.appLoadType), \(labels.dataSource), \(duration.value) ms", domain: .metrics)
        guard duration.unit == UnitDuration.milliseconds else {
            assertionFailure()
            return
        }
        let event = ObservabilityEvent(
            name: "drive_mobile_performance_previewToThumbnail_histogram",
            value: Int(duration.value),
            labels: labels
        )
        ObservabilityEnv.report(event)
    }
}
