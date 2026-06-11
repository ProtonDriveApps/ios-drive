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

@MainActor
public final class DownloadSpeedContainer { // TODO(SDK): add Photos SDK downloader
    private let legacyController: DownloadSpeedController
    private let sdkController: DownloadSpeedController?

    public init(
        legacyDownloader: TrackableDownloader,
        sdkDownloader: TrackableDownloader?,
        processEligibilityController: ProcessEligibilityController
    ) {
        legacyController = DownloadSpeedController(
            downloader: legacyDownloader,
            processEligibilityController: processEligibilityController,
            bytesCounterResource: legacyDownloader.bytesCounterResource,
            timerResource: iOSPausableTimerResource(duration: DownloadSpeedConstants.tickInterval),
            metricResource: ObservabilityDownloadSpeedMetricResource(),
            pipeline: .legacy
        )
        if let sdkDownloader {
            sdkController = DownloadSpeedController(
                downloader: sdkDownloader,
                processEligibilityController: processEligibilityController,
                bytesCounterResource: sdkDownloader.bytesCounterResource,
                timerResource: iOSPausableTimerResource(duration: DownloadSpeedConstants.tickInterval),
                metricResource: ObservabilityDownloadSpeedMetricResource(),
                pipeline: .default
            )
        } else {
            sdkController = nil
        }
    }
}
