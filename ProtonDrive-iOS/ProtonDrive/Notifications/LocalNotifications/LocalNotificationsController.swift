//
//  LocalNotificationsController.swift
//  ProtonDrive
//
//  Created by Aaron HR on 1/25/23.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

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

protocol UserNotificationCenter {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
}

extension UNUserNotificationCenter: UserNotificationCenter { }

final class LocalNotificationsController {
    private var cancellable: AnyCancellable?
    private let notificationCenter: UserNotificationCenter

    private let localNotificationPublisher: LocalNotificationNotifier

    init(
        _ notificationCenter: UserNotificationCenter,
        _ localNotificationPublisher: LocalNotificationNotifier
    ) {
        self.notificationCenter = notificationCenter
        self.localNotificationPublisher = localNotificationPublisher
        self.cancellable = localNotificationPublisher.publisher
            .sink {
                notificationCenter.add(UNNotificationRequest($0), withCompletionHandler: nil)
            }
    }
}
