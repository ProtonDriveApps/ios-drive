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

import Combine
import PDCore
import Foundation
import BackgroundTasks
import ProtonCoreKeymaker
import UserNotifications
import Photos

final class BackgroundPhotoUploadContainer {
    struct Dependencies {
        let workerState: WorkerState
        let appBackgroundStateListener: AnyPublisher<ApplicationRunningState, Never>
        let computationAvailability: ComputationalAvailabilityController
        let backgroundTaskStateController: BackgroundTaskStateController
        let externalFeatureFlagStore: ExternalFeatureFlagsStore
        let settingsProvider: SettingsProvider
        var postLocalNotification = UNUserNotificationCenter.current().post
        let keymaker: Keymaker
        let backgroundTaskResultStateRepository: BackgroundTaskResultStateRepositoryProtocol
    }

    let workerState: WorkerState
    let taskScheduler: BackgroundTaskScheduler
    let backgrounTaskController: ScheduleBackgroundTaskController
    let taskProcessor: TaskProcessor
    let computationAvailability: ComputationalAvailabilityController

    let notifier: BackgroundUploadedPhotoLocalNotifications

    init(dependencies: Dependencies) {

        func makeTaskScheduler(_ workerState: WorkerState) -> BackgroundTaskScheduler {
            let postponedDateProvider: () -> Date
            if Constants.isUITest {
                postponedDateProvider = { Date().byAdding(.minute, value: 15) }
            } else {
                postponedDateProvider = { Date().byAdding(.day, value: 1) }
            }
            
            let ts1 = BackgroundProcessingTaskScheduler(id: Notification.Name.backgroundPhotosProcessing.rawValue, submitTask: BGTaskScheduler.shared.submit, cancelTask: BGTaskScheduler.shared.cancelTask, date: { nil })
            let ts2 = BackgroundProcessingTaskScheduler(id: Notification.Name.backgroundPhotosProcessing.rawValue, submitTask: BGTaskScheduler.shared.submit, cancelTask: BGTaskScheduler.shared.cancelTask, date: postponedDateProvider)
            let lockPolicy = TimeoutLockProtectionEnabledPolicy(settingsProvider: dependencies.settingsProvider, protectionResource: dependencies.keymaker)
            let policy = PhotosTaskSchedulerEnabledPolicy(
                lockPolicy: lockPolicy,
                featureFlagStore: dependencies.externalFeatureFlagStore
            )

            return ConstrainedTaskSchedulerDecorator(
                scheduler: WorkInProgressTaskScheduler(shortTimeTaskScheduler: ts1, longTimeTaskScheduler: ts2, workerState: workerState),
                policy: policy
            )
        }

        func makeScheduleBackgroundTaskController(_ taskScheduler: BackgroundTaskScheduler) -> ScheduleBackgroundTaskController {
            return ScheduleBackgroundTaskController(
                statePublisher: dependencies.appBackgroundStateListener,
                taskScheduler: taskScheduler
            )
        }

        func makeTaskProcessor(_ taskScheduler: BackgroundTaskScheduler, worker: WorkingNotifier) -> TaskProcessor {
            let activator = NotificationCenter.default.getPublisher(for: .backgroundPhotosProcessing, publishing: BackgroundTaskResource.self)
            let disconnector = dependencies.appBackgroundStateListener.filter { $0 == .foreground }.mapAndErase { _ in () }

            let userNotificator = UNLocalNotificationUserNotificator(notificationPoster: dependencies.postLocalNotification)
            let backgroundWorkController = TaskStateBackgroundWorkControllerAdapter(stateController: dependencies.backgroundTaskStateController)
            let notifyingWorkController = TaskStatusNotificatingBackgroundWorkController(userNotificator: userNotificator, decoratee: backgroundWorkController)

            return TaskProcessor(activator: activator, taskDisconnector: disconnector, backgroundWorkController: notifyingWorkController, worker: worker, scheduler: taskScheduler, resultStateRepository: dependencies.backgroundTaskResultStateRepository)
        }

        func makeWorkingNotifier(dependencies: Dependencies) -> WorkingNotifier {
            UploadedPhotoWorkingNotifier(
                workerState: dependencies.workerState,
                backupController: dependencies.computationAvailability,
                uploadedPhotoPublisher: NotificationCenter.default.getPublisher(for: .didUploadPhoto)
            )
        }

        self.workerState = dependencies.workerState
        self.taskScheduler = makeTaskScheduler(workerState)
        self.backgrounTaskController = makeScheduleBackgroundTaskController(taskScheduler)
        self.taskProcessor = makeTaskProcessor(taskScheduler, worker: makeWorkingNotifier(dependencies: dependencies))
        self.computationAvailability = dependencies.computationAvailability
        self.notifier = BackgroundUploadedPhotoLocalNotifications(computationAvailability: computationAvailability, hasUploadedPhotoNotificationEnabled: Constants.uploadedPhotoNotification)
    }
}
