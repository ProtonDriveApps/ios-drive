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
public final class UploadSpeedContainer {
    private let legacyController: UploadSpeedController
    private var sdkController: UploadSpeedController?
    private var sdkPhotoController: UploadSpeedController?

    public init(
        legacyUploadingQueue: TrackableUploadingQueue,
        legacyBytesCounterResource: BytesCounterResource,
        sdkUploader: SDKFileUploaderProtocol?,
        sdkPhotoUploader: SDKFileUploaderProtocol?,
        processEligibilityController: ProcessEligibilityController
    ) {
        legacyController = UploadSpeedController(
            uploadingQueue: legacyUploadingQueue,
            processEligibilityController: processEligibilityController,
            bytesCounterResource: legacyBytesCounterResource,
            timerResource: iOSPausableTimerResource(duration: UploadSpeedConstants.tickInterval),
            metricResource: ObservabilityUploadSpeedMetricResource(),
            pipeline: .legacy
        )
        if let sdkUploader {
            sdkController = UploadSpeedController(
                uploadingQueue: sdkUploader,
                processEligibilityController: processEligibilityController,
                bytesCounterResource: sdkUploader.bytesCounterResource,
                timerResource: iOSPausableTimerResource(duration: UploadSpeedConstants.tickInterval),
                metricResource: ObservabilityUploadSpeedMetricResource(),
                pipeline: .default
            )
        }
        if let sdkPhotoUploader {
            sdkPhotoController = UploadSpeedController(
                uploadingQueue: sdkPhotoUploader,
                processEligibilityController: processEligibilityController,
                bytesCounterResource: sdkPhotoUploader.bytesCounterResource,
                timerResource: iOSPausableTimerResource(duration: UploadSpeedConstants.tickInterval),
                metricResource: ObservabilityUploadSpeedMetricResource(),
                pipeline: .default
            )
        }
    }
}
