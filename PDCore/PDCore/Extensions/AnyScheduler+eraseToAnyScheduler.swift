// Copyright (c) 2023 Proton AG
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

/// A type-erasing scheduler that wraps any scheduler, providing its functionality using the `Scheduler` protocol.
public struct AnyScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler where SchedulerTimeType: Strideable, SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {

    private let _now: () -> SchedulerTimeType
    private let _minimumTolerance: () -> SchedulerTimeType.Stride
    private let _schedule: (SchedulerOptions?, @escaping () -> Void) -> Void
    private let _schedulerAfter: (SchedulerTimeType, SchedulerTimeType.Stride, SchedulerOptions?, @escaping () -> Void) -> Void
    private let _schedulerAfterInterval: (SchedulerTimeType, SchedulerTimeType.Stride, SchedulerTimeType.Stride, SchedulerOptions?, @escaping () -> Void) -> Cancellable

    /// Initializes a new `AnyScheduler` instance with the provided scheduler.
    ///
    /// - Parameter scheduler: The scheduler to wrap.
    public init<S: Scheduler>(_ scheduler: S) where S.SchedulerTimeType == SchedulerTimeType, S.SchedulerOptions == SchedulerOptions {
        self._now = { scheduler.now }
        self._minimumTolerance = { scheduler.minimumTolerance }
        self._schedule = scheduler.schedule(options:_:)
        self._schedulerAfter = scheduler.schedule(after:tolerance:options:_:)
        self._schedulerAfterInterval = scheduler.schedule(after:interval:tolerance:options:_:)
    }

    /// Returns the current time according to the wrapped scheduler.
    public var now: SchedulerTimeType { _now() }

    /// Returns the minimum tolerance allowed by the wrapped scheduler.
    public var minimumTolerance: SchedulerTimeType.Stride { _minimumTolerance() }

    /// Schedules an action to be run as soon as possible.
    ///
    /// - Parameters:
    ///   - options: Scheduler options to use when scheduling.
    ///   - action: The action to be executed.
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        _schedule(options, action)
    }

    /// Schedules an action to be run after a specified date.
    ///
    /// - Parameters:
    ///   - date: The date to execute the action after.
    ///   - tolerance: The tolerance allowed when executing the action.
    ///   - options: Scheduler options to use when scheduling.
    ///   - action: The action to be executed.
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        _schedulerAfter(date, tolerance, options, action)
    }

    /// Schedules a repeating action to be run after a specified date.
    ///
    /// - Parameters:
    ///   - date: The date to start executing the action.
    ///   - interval: The time interval between action executions.
    ///   - tolerance: The tolerance allowed when executing the action.
    ///   - options: Scheduler options to use when scheduling.
    ///   - action: The action to be executed.
    /// - Returns: A cancellable instance which can be used to cancel the scheduled action.
    public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        _schedulerAfterInterval(date, interval, tolerance, options, action)
    }
}

public extension Scheduler {
    /// Erases the type of the current scheduler, returning an `AnyScheduler`.
    ///
    /// - Returns: An `AnyScheduler` wrapping the current scheduler.
    func eraseToAnyScheduler() -> AnyScheduler<SchedulerTimeType, SchedulerOptions> {
        AnyScheduler(self)
    }
}

public typealias AnySchedulerOf<S: Scheduler> = AnyScheduler<S.SchedulerTimeType, S.SchedulerOptions>
