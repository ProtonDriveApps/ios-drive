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
import BackgroundTasks
import PDCore

struct ProcessingBackgroundTaskConfiguration {
    let identifier: String
    let startHandler: () -> Void
    let expirationHandler: () -> Void
}

protocol ProcessingExtensionBackgroundTaskResource {
    func scheduleTask(with configuration: ProcessingBackgroundTaskConfiguration)
    func completeTask(success: Bool)
    func cancelTask()
}

final class ProcessingExtensionBackgroundTaskResourceImpl: ProcessingExtensionBackgroundTaskResource {
    private var configuration: ProcessingBackgroundTaskConfiguration?
    private var cancellables = Set<AnyCancellable>()
    private var task: BGTask?
    
    init() {
        NotificationCenter.default.publisher(for: .scheduleUploads)
            .sink { [weak self] notification in
                guard let task = notification.object as? BGTask else { return }
                self?.launch(task: task)
            }
            .store(in: &cancellables)
    }
    
    func scheduleTask(with configuration: ProcessingBackgroundTaskConfiguration) {
        self.configuration = configuration
        let request = BGProcessingTaskRequest(identifier: configuration.identifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            Log.logInfoAndNotify(title: "✅ background processing scheduled")
        } catch {
            Log.logInfoAndNotify(title: "🐛⚠️ Couldn't schedule app refresh")
        }
    }
    
    func completeTask(success: Bool) {
        if task != nil {
            let message = success ? "with success ✅" : "without success ⚠️"
            Log.logInfoAndNotify(title: "Stop processing task", message: message)
            task?.setTaskCompleted(success: success)
            task = nil
        }
        configuration = nil
    }
    
    func cancelTask() {
        if let identifier = configuration?.identifier {
            Log.logInfoAndNotify(title: "⏸️ Cancel scheduling processing task.")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        }
        completeTask(success: true)
    }
    
    private func launch(task: BGTask) {
        guard self.task == nil else {
            return
        }
        
        Log.logInfoAndNotify(title: "▶️ Launching processing task.")
        self.task = task
        task.expirationHandler = { [weak self] in
            self?.handleExpiration()
        }
        configuration?.startHandler()
    }
    
    private func handleExpiration() {
        guard let configuration = configuration else {
            return
        }
        
        Log.logInfoAndNotify(title: "⏸️ Processing task expired.")
        configuration.expirationHandler()
        task = nil
    }
}
