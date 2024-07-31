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

final class TaskProcessor {
    private let backgroundWorkController: BackgroundWorkController
    private let worker: WorkingNotifier
    private let scheduler: BackgroundTaskScheduler
    private var activatorCancellable: AnyCancellable?
    private var disconnectorCancellable: AnyCancellable?
    private var workerCancellable: AnyCancellable?
    private let resultStateRepository: BackgroundTaskResultStateRepositoryProtocol?

    private weak var task: BackgroundTaskResource?

    init(
        activator: AnyPublisher<BackgroundTaskResource, Never>,
        taskDisconnector: AnyPublisher<Void, Never>,
        backgroundWorkController: BackgroundWorkController,
        worker: WorkingNotifier,
        scheduler: BackgroundTaskScheduler,
        resultStateRepository: BackgroundTaskResultStateRepositoryProtocol?
    ) {
        self.backgroundWorkController = backgroundWorkController
        self.worker = worker
        self.scheduler = scheduler
        self.resultStateRepository = resultStateRepository

        activatorCancellable = activator
            .sink { [weak self] task in
                self?.startWork(task)
            }

        disconnectorCancellable = taskDisconnector
            .sink{ [weak self] in
                guard let self, let task = task else { return }
                Log.info("\(task.identifier) interrupted (app moved to foreground)", domain: .backgroundTask)
                self.resultStateRepository?.setState(.foreground)
                self.completeWork(for: task, isSuccess: true)
            }
    }

    private func startWork(_ task: BackgroundTaskResource) {
        task.expirationHandler = { [weak self, weak task] in
            guard let self, let task = task else { return }
            Log.info("\(task.identifier) expired", domain: .backgroundTask)
            self.resultStateRepository?.setState(.expired)
            self.completeWork(for: task, isSuccess: false)
        }

        workerCancellable = worker.isWorkingPublisher
            .sink { [weak self, weak task] isWorking in
                guard let self, let task = task else { return }
                guard !isWorking else { return }

                Log.info("\(task.identifier) completed, worker finished working", domain: .backgroundTask)
                self.resultStateRepository?.setState(.completed)
                self.completeWork(for: task, isSuccess: true)
            }

        Log.info("\(task.identifier) will start", domain: .backgroundTask)
        self.task = task
        backgroundWorkController.start()
    }

    private func completeWork(for task: BackgroundTaskResource?, isSuccess: Bool) {
        scheduler.schedule()
        backgroundWorkController.stop()
        task?.setTaskCompleted(success: isSuccess)
    }
}
