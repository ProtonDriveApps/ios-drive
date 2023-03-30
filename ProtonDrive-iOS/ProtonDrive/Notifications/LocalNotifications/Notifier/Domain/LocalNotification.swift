//
//  LocalNotification.swift
//  ProtonDrive
//
//  Created by Aaron HR on 1/30/23.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Foundation

struct LocalNotification: Equatable {
    let id: UUID
    let title: String
    let body: String
    let thread: String
    let delay: TimeInterval

    static var interruptedUpload: LocalNotification {
        LocalNotification(
            id: UUID(),
            title: "Proton Drive",
            body: "Your upload is paused. Open the app to resume.",
            thread: "ch.protondrive.usernotification.uploadIncomplete",
            delay: 1.0
        )
    }

    static var failedUpload: LocalNotification {
        LocalNotification(
            id: UUID(),
            title: "Proton Drive",
            body: "Some files didn’t upload. Try uploading them again.",
            thread: "ch.protondrive.usernotification.uploadFailure",
            delay: 1.0
        )
    }
}
