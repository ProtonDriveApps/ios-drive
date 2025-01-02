// Copyright (c) 2023 Proton AG
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
import PDCore

final class MyFilesNotificationsPermissionsController: NotificationsPermissionsController {
    private let flowController: NotificationsPermissionsFlowController
    private let resource: LocalNotificationsResource
    private let uploadInteractor: OperationInteractor
    private let localSettings: LocalSettings
    private var uploadCancellable: AnyCancellable?
    private var permissionsCancellable: AnyCancellable?

    init(flowController: NotificationsPermissionsFlowController, resource: LocalNotificationsResource, uploadInteractor: OperationInteractor, localSettings: LocalSettings) {
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
                flowController.event.send(.openFileNotification)
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
