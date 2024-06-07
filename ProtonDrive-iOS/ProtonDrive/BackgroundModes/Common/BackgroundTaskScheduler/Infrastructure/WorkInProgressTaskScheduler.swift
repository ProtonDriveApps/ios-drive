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

import PDCore

public final class WorkInProgressTaskScheduler: BackgroundTaskScheduler {
    private let workerState: WorkerState
    private let shortTimeTaskScheduler: BackgroundTaskScheduler
    private let longTimeTaskScheduler: BackgroundTaskScheduler

    public init(
        shortTimeTaskScheduler: BackgroundTaskScheduler,
        longTimeTaskScheduler: BackgroundTaskScheduler,
        workerState: WorkerState
    ) {
        self.shortTimeTaskScheduler = shortTimeTaskScheduler
        self.longTimeTaskScheduler = longTimeTaskScheduler
        self.workerState = workerState
    }

    public func schedule() {
        if workerState.isWorking {
            shortTimeTaskScheduler.schedule()
        } else {
            longTimeTaskScheduler.schedule()
        }
    }

    public func cancel() {
        shortTimeTaskScheduler.cancel()
        longTimeTaskScheduler.cancel()
    }
}
