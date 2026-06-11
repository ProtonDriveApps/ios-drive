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

import Foundation

/// Periodically collects process-level and system-wide CPU/memory metrics
/// and logs them using JSONLogger.
public final class SystemMetricsMonitor {
    private let collector: SystemMetricsCollector
    private let interval: TimeInterval
    private var timer: Timer?

    /// - Parameters:
    ///   - interval: Seconds between each metrics snapshot.
    ///   - volumeURL: Optional URL on the FileProvider volume to track free disk space.
    public init(interval: TimeInterval, volumeURL: URL? = nil) {
        self.interval = interval
        self.collector = SystemMetricsCollector(volumeURL: volumeURL)
    }

    public func start() {
        guard timer == nil else { return }

        logSnapshot()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.logSnapshot()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }

    private func logSnapshot() {
        guard let snapshot = collector.collect() else { return }
        Log.systemMetrics(snapshot)
    }
}
