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
