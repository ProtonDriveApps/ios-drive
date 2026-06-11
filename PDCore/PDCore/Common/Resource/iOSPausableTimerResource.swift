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

import Combine
import Foundation

public final class iOSPausableTimerResource: PausableTimerResource {
    private var timer: Timer?
    private var subject = PassthroughSubject<Void, Never>()
    private let duration: TimeInterval
    private var startTime: Double?

    // Cumulative time since an interval start. It resets after interval finishes or if the timer is stopped.
    // E.g. - start timer {event1}, pause {event2}, resume {event3}, stop {event4}
    // - the result should be sum of intervals {event1} - {event2} and {event3} - {event4}
    private var elapsedTime: Double = 0

    /// Timer invalidation is not enough to consistently pause/stop this timer. When we call `timer.invalidate()`,
    /// `.isValid` immediately becomes false, but the RunLoop might still fire the timer elapsed block. Thus, we need to
    /// track whether to send an update to our publisher and recreate the timer in `handleIntervalEnd` ourselves.
    private var hasStopBeenRequested = true

    public var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    public var isRunning: Bool {
        timer?.isValid ?? false
    }

    /// `duration`: in seconds
    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func resume() {
        hasStopBeenRequested = false

        guard !isRunning else {
            return
        }

        startTime = Date.timeIntervalSinceReferenceDate
        let interval = max(duration - elapsedTime, 0)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.handleIntervalEnd()
        }

        self.timer = timer

        RunLoop.current.add(timer, forMode: .common)
    }

    public func pause() {
        hasStopBeenRequested = true

        guard isRunning else {
            return
        }
        elapsedTime += Date.timeIntervalSinceReferenceDate - (startTime ?? 0.0)
        timer?.invalidate()
    }

    public func stop() {
        hasStopBeenRequested = true

        timer?.invalidate()
        elapsedTime = 0
    }

    public func restart() {
        stop()
        resume()
    }

    public func getElapsedTime() -> TimeInterval {
        if isRunning {
            return elapsedTime + Date.timeIntervalSinceReferenceDate - (startTime ?? 0.0)
        } else {
            return elapsedTime
        }
    }

    private func handleIntervalEnd() {
        timer?.invalidate()

        if !hasStopBeenRequested {
            elapsedTime += Date.timeIntervalSinceReferenceDate - (startTime ?? 0.0)
            subject.send()
            elapsedTime = 0
            resume()
        } else {
            elapsedTime = 0
        }
    }
}
