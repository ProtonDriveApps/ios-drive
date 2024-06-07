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
import Combine
import UserNotifications

/*
Requirements:
 [✅] Request permision for showing local notifications
    Permission will be requested everytime we try to upload a file, the system will show an alert the first time that we ask for permissions, but not subsequently. The method used for asking for permissions is asynchronous.
 [✅] Show a local notification when the upload is cancelled or the file upload fails when we are in the background, and just one per upload session. A session is considered to be everytime that the user sends the app to the background. In this case if a user is uploading 3 files: a,b,c.

 If a in the foreground:
- No alert is shown
 If a finishes in the foreground and b fails in the background and c is paused on the background
- One alert
 If a finishes in the foreground and b fails in the background we bring back to the foreground while c is uploading and send it back to the background and then and c is paused:
- Two alerts
*/

final class LocalNotificationsController {
    private var cancellable: AnyCancellable?
    private let resource: LocalNotificationsResource

    private let localNotificationPublisher: LocalNotificationNotifier

    init(
        _ resource: LocalNotificationsResource,
        _ localNotificationPublisher: LocalNotificationNotifier
    ) {
        self.resource = resource
        self.localNotificationPublisher = localNotificationPublisher
        self.cancellable = localNotificationPublisher.publisher
            .sink {
                resource.addRequest(with: $0)
            }
    }
}
