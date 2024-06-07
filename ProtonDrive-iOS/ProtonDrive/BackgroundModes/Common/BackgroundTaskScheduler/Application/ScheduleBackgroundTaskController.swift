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
import Combine

public final class ScheduleBackgroundTaskController {
    private let statePublisher: AnyPublisher<ApplicationRunningState, Never>
    private let taskScheduler: BackgroundTaskScheduler
    private var cancellables = Set<AnyCancellable>()

    public init(
        statePublisher: AnyPublisher<ApplicationRunningState, Never>,
        taskScheduler: BackgroundTaskScheduler
    ) {
        self.statePublisher = statePublisher
        self.taskScheduler = taskScheduler

        statePublisher.sink { [weak self] state in
            self?.handle(state)
        }
        .store(in: &cancellables)
    }

    private func handle(_ appState: ApplicationRunningState) {
        switch appState {
        case .background:
            taskScheduler.schedule()
        case .foreground:
            taskScheduler.cancel()
        }
    }
}
