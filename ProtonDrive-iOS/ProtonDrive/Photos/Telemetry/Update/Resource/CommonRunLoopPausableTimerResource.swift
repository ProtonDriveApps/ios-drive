// Copyright (c) 2024 Proton AG
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

protocol PausableTimerResource {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func resume()
    func pause()
}

final class CommonRunLoopPausableTimerResource: PausableTimerResource {
    private var timer: Timer?
    private var subject = PassthroughSubject<Void, Never>()
    private let duration: Double
    private var startTime: Double?
    private var elapsedTime: Double = 0

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(duration: Double) {
        self.duration = duration
    }

    func resume() {
        guard timer == nil else {
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

    func pause() {
        guard timer != nil else {
            return
        }

        elapsedTime = Date.timeIntervalSinceReferenceDate - (startTime ?? 0.0)
        timer?.invalidate()
        timer = nil
    }

    private func handleIntervalEnd() {
        timer = nil
        subject.send()
        elapsedTime = 0
        resume()
    }
}
