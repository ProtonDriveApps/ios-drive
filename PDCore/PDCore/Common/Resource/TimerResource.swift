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

public protocol ScheduledTimerHandle {
    func invalidate()
}

public protocol TimerResource {
    func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        callback: @escaping () -> Void
    ) -> ScheduledTimerHandle
}

public final class PlatformTimerResource: TimerResource {
    public init() {}

    public func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        callback: @escaping () -> Void
    ) -> ScheduledTimerHandle {
        DispatchSourceTimerHandle(interval: interval, repeats: repeats, callback: callback)
    }
}

private final class DispatchSourceTimerHandle: ScheduledTimerHandle {
    private let source: DispatchSourceTimer

    init(interval: TimeInterval, repeats: Bool, callback: @escaping () -> Void) {
        source = DispatchSource.makeTimerSource(queue: .main)
        if repeats {
            source.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(30))
        } else {
            source.schedule(deadline: .now() + interval, leeway: .seconds(30))
        }
        source.setEventHandler(handler: callback)
        source.resume()
    }

    deinit {
        source.cancel()
    }

    func invalidate() {
        source.cancel()
    }
}
