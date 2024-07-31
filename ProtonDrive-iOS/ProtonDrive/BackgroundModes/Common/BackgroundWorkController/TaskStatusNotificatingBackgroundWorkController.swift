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

final class TaskStatusNotificatingBackgroundWorkController: BackgroundWorkController {
    let userNotificator: UserNotificator
    let decoratee: BackgroundWorkController

    init(userNotificator: UserNotificator, decoratee: BackgroundWorkController) {
        self.userNotificator = userNotificator
        self.decoratee = decoratee
    }

    func start() {
        #if HAS_QA_FEATURES
        userNotificator.notify(.backgroundUploadLaunched)
        #endif
        decoratee.start()
    }

    func stop() {
        #if HAS_QA_FEATURES
        userNotificator.notify(.backgroundUploadFinished)
        #endif
        decoratee.stop()
    }
}

private extension LocalNotification {
    static var backgroundUploadLaunched: LocalNotification {
        LocalNotification(id: UUID().uuidString, title: "Proton Drive", body: "Background upload launched ✅", thread: "ch.protondrive.usernotification.photosBackground", delay: .leastNonzeroMagnitude)
    }

    static var backgroundUploadFinished: LocalNotification {
        LocalNotification(id: UUID().uuidString, title: "Proton Drive", body: "Background upload ended ❌", thread: "ch.protondrive.usernotification.photosBackground", delay: .leastNonzeroMagnitude)
    }
}
