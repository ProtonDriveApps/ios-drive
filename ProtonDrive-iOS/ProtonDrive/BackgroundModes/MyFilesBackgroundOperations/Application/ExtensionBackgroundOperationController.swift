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

final class ExtensionBackgroundOperationController: BackgroundOperationController {
    #if SUPPORTS_BACKGROUND_UPLOADS
    private let processingController: BackgroundOperationController
    #endif
    private let extensionStateController: BackgroundTaskStateController
    private let operationInteractor: OperationInteractor
    private let taskResource: ExtensionBackgroundTaskResource
    private var interactorCancellable: AnyCancellable?
    private var isRunning = false

    #if SUPPORTS_BACKGROUND_UPLOADS
    init(
        processingController: BackgroundOperationController,
        extensionStateController: BackgroundTaskStateController,
        operationInteractor: OperationInteractor,
        taskResource: ExtensionBackgroundTaskResource
    ) {
        self.processingController = processingController
        self.extensionStateController = extensionStateController
        self.operationInteractor = operationInteractor
        self.taskResource = taskResource
    }
    #else
    init(
        extensionStateController: BackgroundTaskStateController,
        operationInteractor: OperationInteractor,
        taskResource: ExtensionBackgroundTaskResource
    ) {
        self.extensionStateController = extensionStateController
        self.operationInteractor = operationInteractor
        self.taskResource = taskResource
    }
    #endif

    func start() {
        switch operationInteractor.state {
        case .idle:
            break
        case .running:
            startExecution()
        }
    }

    private func startExecution() {
        subscribeToInteractor()
        isRunning = true
        extensionStateController.start()
        taskResource.scheduleTask { [weak self] in
            self?.expire()
        }
    }

    func stop() {
        isRunning = false
        #if SUPPORTS_BACKGROUND_UPLOADS
        processingController.stop()
        #endif
        taskResource.cancelTask()
        interactorCancellable = nil
        extensionStateController.stop()
    }
    
    private func expire() {
        interactorCancellable = nil
        isRunning = false
        operationInteractor.cancel()
        #if SUPPORTS_BACKGROUND_UPLOADS
        processingController.start()
        #endif
        taskResource.cancelTask()
        extensionStateController.stop()
    }

    private func subscribeToInteractor() {
        interactorCancellable = operationInteractor.updatePublisher
            .filter { [weak self] in
                self?.operationInteractor.state == .idle && self?.isRunning == true
            }
            .sink { [weak self] in
                self?.stop()
            }
    }
}
