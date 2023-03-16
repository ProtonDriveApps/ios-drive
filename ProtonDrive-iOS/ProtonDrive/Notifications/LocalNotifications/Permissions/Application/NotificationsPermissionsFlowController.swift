//
//  NotificationsPermissionsFlowController.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 02.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Combine

enum NotificationsPermissionsEvent {
    case open
    case close
}

protocol NotificationsPermissionsFlowController {
    var event: PassthroughSubject<NotificationsPermissionsEvent, Never> { get }
}

final class NotificationsPermissionsFlowControllerImpl: NotificationsPermissionsFlowController {
    let event: PassthroughSubject<NotificationsPermissionsEvent, Never> = .init()
}
