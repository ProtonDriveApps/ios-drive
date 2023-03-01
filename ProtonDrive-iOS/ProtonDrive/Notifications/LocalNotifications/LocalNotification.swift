//
//  LocalNotification.swift
//  ProtonDrive
//
//  Created by Aaron HR on 1/30/23.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Foundation
import UserNotifications

struct LocalNotification: Equatable {
    let id: UUID
    let title: String
    let body: String
    let thread: String
    let delay: TimeInterval

    static var incompleteUpload: LocalNotification {
        LocalNotification(
            id: UUID(),
            title: "Proton Drive",
            body: "Some files didn’t upload. Try uploading them again.",
            thread: "ch.protondrive.usernotification.uploadfailure",
            delay: 1.0
        )
    }
}

extension UNNotificationRequest {
    convenience init(_ localNotification: LocalNotification) {
        let content = UNMutableNotificationContent()
        content.title = localNotification.title
        content.body = localNotification.body
        content.threadIdentifier = localNotification.thread

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: localNotification.delay,
            repeats: false
        )

        self.init(
            identifier: localNotification.id.uuidString,
            content: content,
            trigger: trigger
        )
    }
}
