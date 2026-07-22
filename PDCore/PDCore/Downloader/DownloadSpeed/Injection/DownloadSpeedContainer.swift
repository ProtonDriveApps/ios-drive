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

#if os(iOS)

import Foundation

@MainActor
public final class DownloadSpeedContainer {
    private let sdkFileController: DownloadSpeedController
    private let sdkPhotoController: DownloadSpeedController

    public init(
        sdkFileDownloader: TrackableDownloader,
        sdkPhotoDownloader: TrackableDownloader,
        processEligibilityController: ProcessEligibilityController
    ) {
        sdkFileController = DownloadSpeedController(
            downloader: sdkFileDownloader,
            processEligibilityController: processEligibilityController,
            bytesCounterResource: sdkFileDownloader.bytesCounterResource,
            timerResource: iOSPausableTimerResource(duration: DownloadSpeedConstants.tickInterval),
            metricResource: ObservabilityDownloadSpeedMetricResource(),
            pipeline: .default
        )

        sdkPhotoController = DownloadSpeedController(
            downloader: sdkPhotoDownloader,
            processEligibilityController: processEligibilityController,
            bytesCounterResource: sdkPhotoDownloader.bytesCounterResource,
            timerResource: iOSPausableTimerResource(duration: DownloadSpeedConstants.tickInterval),
            metricResource: ObservabilityDownloadSpeedMetricResource(),
            pipeline: .default
        )
    }
}

#endif
