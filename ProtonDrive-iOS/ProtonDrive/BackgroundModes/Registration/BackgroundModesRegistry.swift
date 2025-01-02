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

import Foundation
import PDCore
import BackgroundTasks

final class BackgroundModesRegistry {
    private static var tasks: [CompleteRegisteringBackgroundTask] = []

    static func register() {
        #if SUPPORTS_BACKGROUND_UPLOADS
        registerMyFilesBackgroundUploads()
        #endif

        registerPhotosNotificationReminder()
        registerPhotosBackgroundUploads()
    }

    private func registerMyFilesBackgroundUploads() {
        Log.info("Will register \(Constants.backgroundTaskIdentifier)", domain: .backgroundTask)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Constants.backgroundTaskIdentifier, using: nil) {
            Log.info("Start processing background task", domain: .backgroundTask)
            NotificationCenter.default.post(name: .scheduleUploads, object: $0)
        }
    }

    private static func registerPhotosNotificationReminder() {
        registerBackgroundTask(.checkNewPhotoInGallery)
    }

    private static func registerPhotosBackgroundUploads() {
        registerBackgroundTask(.photosProcessing)
    }

    static func registerBackgroundTask(_ backgroundMode: BackgroundModes) {
        Log.info("Will register \(backgroundMode)", domain: .backgroundTask)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundMode.id, using: nil) { task in
            Log.info("Start processing BG task \(backgroundMode) 🚦", domain: .backgroundTask)
            let task = CompleteRegisteringBackgroundTask(task: task)
            DispatchQueue.main.async {
                appendTask(task)
                NotificationCenter.default.post(name: backgroundMode.notification, object: task)
            }
        }
    }

    static func appendTask(_ task: CompleteRegisteringBackgroundTask) {
        tasks = tasks.filter { !$0.isCompleted }
        tasks.append(task)
    }
}
