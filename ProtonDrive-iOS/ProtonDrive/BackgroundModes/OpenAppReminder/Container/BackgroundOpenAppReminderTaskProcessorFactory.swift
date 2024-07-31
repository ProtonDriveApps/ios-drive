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

import Photos
import PDCore
import Combine
import BackgroundTasks
import UserNotifications

final class BackgroundOpenAppReminderTaskProcessorFactory {
    struct Dependencies {
        var photoUploadsWorkerState: WorkerState
        var backgroundTaskScheduler: BackgroundTaskScheduler
        var backgroundWorkPolicy: BackgroundWorkPolicy
        var activator = BackgroundModes.checkNewPhotoInGallery.publisher
        var postLocalNotification = UNUserNotificationCenter.current().post
    }

    func makeOpenPhotosNotificationTaskProcessor(_ dependencies: Dependencies) -> TaskProcessor {
        // Disconnector is used to stop the task processor when the app goes to the foreground and the task is running, not necessary in this setup because we fire the local notification immediately
        let disconnector = Empty<Void, Never>().eraseToAnyPublisher()

        // WorkStatusController is used to stop the worker when the task is finished early, will always happen in this setup because we jsut check if we need to fire and fire the notification or not
        let workStatusController = WorkStatusPublishingController()

        // UserNotificator is used to post a notification when there is a non-backed up photo in the gallery
        let userNotificator = UNLocalNotificationUserNotificator(notificationPoster: dependencies.postLocalNotification)
        // NotifyingController is used to show the user a local notification when there is a non-backed up photo in the gallery
        let notifyingController = OpenPhotosNotificatingBackgroundWorkController(photosUploadWorker: dependencies.photoUploadsWorkerState, userNotificator: userNotificator, backgroundWorkPolicy: dependencies.backgroundWorkPolicy)
        // EarlyExitingController is used to stop the background task once we post the local notification
        let earlyExitingController = EarlyExitPublishingBackgroundWorkController(decoratee: notifyingController, workStatusController: workStatusController)
        // TaskProcessor coordinates the work during background task
        return TaskProcessor(activator: dependencies.activator, taskDisconnector: disconnector, backgroundWorkController: earlyExitingController, worker: workStatusController, scheduler: dependencies.backgroundTaskScheduler, resultStateRepository: nil)
    }
}

extension UNUserNotificationCenter {
    func post(_ request: UNNotificationRequest) {
        add(request, withCompletionHandler: nil)
    }
}
