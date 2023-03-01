//
//  NotificationsPermissionsViewModel.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 01.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Foundation

protocol NotificationsPermissionsViewModel {
    func enable()
    func skip()
    func close()
}

final class NotificationsPermissionsViewModelImpl: NotificationsPermissionsViewModel {
    private let controller: NotificationsPermissionsController
    private let flowController: NotificationsPermissionsFlowController
    
    init(controller: NotificationsPermissionsController, flowController: NotificationsPermissionsFlowController) {
        self.controller = controller
        self.flowController = flowController
    }
    
    func enable() {
        controller.requestPermissions()
    }

    func skip() {
        controller.skip()
        close()
    }
    
    func close() {
        flowController.event.send(.close)
    }
}
