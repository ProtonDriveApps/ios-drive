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
import PDCore

final class ProcessingBackgroundOperationController: BackgroundOperationController {
    private let operationInteractor: OperationInteractor
    private let taskResource: ProcessingExtensionBackgroundTaskResource
    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false
    
    init(operationInteractor: OperationInteractor, taskResource: ProcessingExtensionBackgroundTaskResource) {
        self.operationInteractor = operationInteractor
        self.taskResource = taskResource
        subscribeToInteractor()
    }
    
    func start() {
        taskResource.scheduleTask(with: makeConfiguration())
    }
    
    func stop() {
        isRunning = false
        taskResource.cancelTask()
    }
    
    private func scheduleTask() {
        taskResource.scheduleTask(with: makeConfiguration())
    }
    
    private func subscribeToInteractor() {
        operationInteractor.updatePublisher
            .filter { [weak self] in
                self?.operationInteractor.state == .idle && self?.isRunning == true
            }
            .sink { [weak self] in
                self?.stop()
            }
            .store(in: &cancellables)
    }
    
    private func makeConfiguration() -> ProcessingBackgroundTaskConfiguration {
        ProcessingBackgroundTaskConfiguration(
            identifier: Constants.backgroundTaskIdentifier,
            startHandler: { [weak self] in
                self?.isRunning = true
                self?.operationInteractor.start()
            },
            expirationHandler: { [weak self] in
                self?.expireTask()
            }
        )
    }
    
    private func expireTask() {
        isRunning = false
        if operationInteractor.state == .idle {
            ConsoleLogger.shared?.logAndNotify(title: "✅ task finished", message: "", osLogType: Constants.self)
            taskResource.completeTask(success: true)
        } else {
            ConsoleLogger.shared?.logAndNotify(title: "⚠️ task expired", message: "", osLogType: Constants.self)
            operationInteractor.cancel()
            scheduleTask()
            taskResource.completeTask(success: false)
        }
    }
}
