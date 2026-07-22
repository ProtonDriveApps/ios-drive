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

import Combine
import Foundation

struct DownloadSpeedConstants {
    static let tickInterval: TimeInterval = 60
}

@MainActor
final class DownloadSpeedController {
    private let downloader: TrackableDownloader
    private let processEligibilityController: ProcessEligibilityController
    private let bytesCounterResource: BytesCounterResource
    private let timerResource: PausableTimerResource
    private let metricResource: DownloadSpeedMetricResource
    private var cancellables = Set<AnyCancellable>()
    private var isMeasuring = false
    private var isInBackground = false
    private let pipeline: DriveObservabilityPipeline

    init(
        downloader: TrackableDownloader,
        processEligibilityController: ProcessEligibilityController,
        bytesCounterResource: BytesCounterResource,
        timerResource: PausableTimerResource,
        metricResource: DownloadSpeedMetricResource,
        pipeline: DriveObservabilityPipeline
    ) {
        self.downloader = downloader
        self.processEligibilityController = processEligibilityController
        self.bytesCounterResource = bytesCounterResource
        self.timerResource = timerResource
        self.metricResource = metricResource
        self.pipeline = pipeline
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(processEligibilityController.processEligibility, downloader.isActivePublisher)
            .sink { [weak self] eligibility, isActivelyDownloading in
                self?.updateState(isDownloaderActive: isActivelyDownloading, eligibility: eligibility)
            }
            .store(in: &cancellables)

        timerResource.updatePublisher
            .sink { [weak self] in
                self?.sendMeasurement()
            }
            .store(in: &cancellables)
    }

    private func updateState(isDownloaderActive: Bool, eligibility: ProcessEligibility) {
        switch eligibility {
        case .eligibleInForeground:
            updateMeasuringIfNeeded(isDownloaderActive: isDownloaderActive, isInBackground: false)
        case .eligibleInBackground:
            updateMeasuringIfNeeded(isDownloaderActive: isDownloaderActive, isInBackground: true)
        case .ineligible:
            pauseMeasuringIfNeeded()
        }
    }

    private func pauseMeasuringIfNeeded() {
        if isMeasuring {
            isMeasuring = false
            timerResource.pause()
            Log.debug("Pausing tracking", domain: .metrics)
        }
    }

    private func updateMeasuringIfNeeded(isDownloaderActive: Bool, isInBackground: Bool) {
        self.isInBackground = isInBackground

        if isDownloaderActive {
            // Disclaimer: in some cases eligibility changes to `ineligible` before downloader actually pauses.
            // The called functions should account for this, i.e. don't expect downloader stops before eligibility etc.
            // For this reason we're intentionally not checking `isMeasuring` since multiple active events can occur.
            // This is suboptimality of `TrackableDownloader`, which atm isn't explicitly stopped when process ineligibility is set.
            isMeasuring = true
            timerResource.resume()
            Log.debug("Resuming/continuing tracking", domain: .metrics)
        } else if isMeasuring {
            isMeasuring = false
            sendMeasurement()
            timerResource.stop()
            Log.debug("Stopped tracking and sent update", domain: .metrics)
        }
    }

    private func sendMeasurement() {
        let secondsCount = timerResource.getElapsedTime()
        guard secondsCount > 0 else {
            return
        }

        let bytes = bytesCounterResource.getBytesCount()
        bytesCounterResource.reset()
        let kibiBytes = Double(bytes) / Double(1024)
        let speedInKiBps = Int((kibiBytes / secondsCount).rounded())
        Log.debug("Measured: \(kibiBytes) KiB downloaded in \(secondsCount) seconds", domain: .metrics)
        metricResource.sendMetric(speed: speedInKiBps, isBackground: isInBackground, pipeline: pipeline)
    }
}

#endif
