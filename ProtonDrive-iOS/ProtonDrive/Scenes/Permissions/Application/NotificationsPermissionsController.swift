//
//  NotificationsPermissionsController.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 02.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Combine
import PDCore
 
protocol NotificationsPermissionsController {
    func requestPermissions()
    func skip()
}

final class NotificationsPermissionsControllerImpl: NotificationsPermissionsController {
    private let flowController: NotificationsPermissionsFlowController
    private let resource: LocalNotificationPermissionsResource
    private let uploadInteractor: OperationInteractor
    private let localSettings: LocalSettings
    private var uploadCancellable: AnyCancellable?
    private var permissionsCancellable: AnyCancellable?
    
    init(flowController: NotificationsPermissionsFlowController, resource: LocalNotificationPermissionsResource, uploadInteractor: OperationInteractor, localSettings: LocalSettings) {
        self.flowController = flowController
        self.resource = resource
        self.uploadInteractor = uploadInteractor
        self.localSettings = localSettings
        subscribe()
    }
    
    private func subscribe() {
        guard localSettings.isNoticationPermissionsSkipped != true else {
            return
        }

        uploadCancellable = uploadInteractor.updatePublisher
            .filter { [unowned self] in
                uploadInteractor.state == .running
            }
            .flatMap { [unowned self] in
                resource.isRequestable()
            }
            .filter { $0 }
            .sink { [unowned self] _ in
                flowController.event.send(.open)
            }
    }
    
    func requestPermissions() {
        permissionsCancellable = resource.requestPermissions()
            .sink { [unowned self] in
                flowController.event.send(.close)
            }
    }

    func skip() {
        localSettings.isNoticationPermissionsSkipped = true
        uploadCancellable = nil
    }
}
