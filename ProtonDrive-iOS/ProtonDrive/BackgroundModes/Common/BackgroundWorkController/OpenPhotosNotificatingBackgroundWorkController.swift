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

class OpenPhotosNotificatingBackgroundWorkController: BackgroundWorkController {
    let photosUploadWorker: WorkerState
    let userNotificator: UserNotificator
    let backgroundWorkPolicy: BackgroundWorkPolicy

    init(
        photosUploadWorker: WorkerState,
        userNotificator: UserNotificator,
        backgroundWorkPolicy: BackgroundWorkPolicy
    ) {
        self.photosUploadWorker = photosUploadWorker
        self.userNotificator = userNotificator
        self.backgroundWorkPolicy = backgroundWorkPolicy
    }

    func start() {
        if backgroundWorkPolicy.canExecute && photosUploadWorker.isWorking {
            userNotificator.notify(.remindOpenApp)
        }
    }

    func stop() {

    }
}

extension LocalNotification {
    static var remindOpenApp: LocalNotification {
        LocalNotification(id: UUID().uuidString, title: "Proton Drive", body: "Check in with Proton Drive to confirm your photos are backed up and secure.", thread: "ch.protondrive.usernotification.photosUploadReminder", delay: .leastNonzeroMagnitude)
    }
}
