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

public struct ImmediateScheduler<SchedulerTimeType: Strideable, SchedulerOptions>: Scheduler where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {
    public let now: SchedulerTimeType
    public let minimumTolerance: SchedulerTimeType.Stride = .zero

    public init(now: SchedulerTimeType) {
        self.now = now
    }

    public func schedule(options: SchedulerOptions?, _ action: () -> Void) {
        action()
    }

    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: () -> Void) {
        action()
    }

    public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        action()
        return AnyCancellable {}
    }
}

public typealias ImmediateSchedulerOf<S: Scheduler> = ImmediateScheduler<S.SchedulerTimeType, S.SchedulerOptions>

public extension DispatchQueue {
    static var immediate: ImmediateSchedulerOf<DispatchQueue> {
        ImmediateScheduler(now: .init(.init(uptimeNanoseconds: 1)))
    }
}

public extension AnySchedulerOf<DispatchQueue> {
    static var immediate: Self {
        DispatchQueue.immediate.eraseToAnyScheduler()
    }
}
