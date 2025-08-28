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

public protocol CombineDebounceResource {
    func debounce<R, E, S>(
        publisher: AnyPublisher<R, E>,
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<R, E> where S: Scheduler
}

public final class ScheduleDebounceResource: CombineDebounceResource {
    public init() {}
    
    public func debounce<R, E, S>(
        publisher: AnyPublisher<R, E>,
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<R, E> where S: Scheduler {
        publisher
            .debounce(for: dueTime, scheduler: scheduler)
            .eraseToAnyPublisher()
    }
}
