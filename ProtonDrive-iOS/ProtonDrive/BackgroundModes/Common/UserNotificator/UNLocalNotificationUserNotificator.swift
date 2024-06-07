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

import UserNotifications

final class UNLocalNotificationUserNotificator: UserNotificator {

    private let notificationPoster: (UNNotificationRequest) -> Void

    init(notificationPoster: @escaping (UNNotificationRequest) -> Void) {
        self.notificationPoster = notificationPoster
    }

    func notify(_ localNotification: LocalNotification) {
        let content = UNMutableNotificationContent()
        content.title = localNotification.title
        content.body = localNotification.body
        content.threadIdentifier = localNotification.thread
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: localNotification.delay, repeats: false)
        let request = UNNotificationRequest(identifier: localNotification.id.uuidString, content: content, trigger: trigger)
        notificationPoster(request)
    }
}
