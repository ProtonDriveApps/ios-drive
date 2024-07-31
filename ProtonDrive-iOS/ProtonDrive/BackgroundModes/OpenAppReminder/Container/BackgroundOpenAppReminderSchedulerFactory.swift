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
import BackgroundTasks
import UserNotifications

final class BackgroundOpenAppReminderSchedulerFactory {
    struct Dependencies {
        var submitTask: (BGAppRefreshTaskRequest) throws -> Void = BGTaskScheduler.shared.submit
        var cancelTask: (String) -> Void = BGTaskScheduler.shared.cancelTask
        var dateProvider: () -> Date? = Date.init
        var hasDefaultScheduleDelay: () -> Bool = { Constants.hasPhotosReminderStandardDelay }
        var enabledPolicy: TaskSchedulerPolicy
    }

    func makeTaskScheduler(dependencies: Dependencies) -> BackgroundTaskScheduler {
        let scheduledDate = dependencies.hasDefaultScheduleDelay() ? { dependencies.dateProvider() } : { nil }

        let scheduler = BackgroundAppRefreshTaskScheduler(
            id: BackgroundModes.checkNewPhotoInGallery.id,
            submitTask: dependencies.submitTask,
            cancelTask: dependencies.cancelTask,
            date: scheduledDate
        )
        return ConstrainedTaskSchedulerDecorator(scheduler: scheduler, policy: dependencies.enabledPolicy)
    }
}
