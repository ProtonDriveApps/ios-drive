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

final class PhotosLocalNotificationsPermissionsController: NotificationsPermissionsController {
    private let flowController: NotificationsPermissionsFlowController
    private let resource: LocalNotificationsResource
    private let backupAvailableController: PhotosBackupUploadAvailableController
    private let localSettings: LocalSettings
    private var uploadCancellable: AnyCancellable?
    private var permissionsCancellable: AnyCancellable?

    init(flowController: NotificationsPermissionsFlowController, resource: LocalNotificationsResource, backupAvailableController: PhotosBackupUploadAvailableController, localSettings: LocalSettings) {
        self.flowController = flowController
        self.resource = resource
        self.backupAvailableController = backupAvailableController
        self.localSettings = localSettings
        subscribe()
    }

    private func subscribe() {
        guard localSettings.isPhotosNotificationsPermissionsSkipped != true else {
            return
        }

        uploadCancellable = backupAvailableController.isAvailable
            .filter { $0 }
            .flatMap { [unowned self] _ in
                resource.isRequestable()
            }
            .filter { $0 }
            .sink { [unowned self] _ in
                flowController.event.send(.openPhotoNotification)
            }
    }

    func requestPermissions() {
        permissionsCancellable = resource.requestPermissions()
            .sink { [unowned self] in
                flowController.event.send(.close)
            }
    }

    func skip() {
        localSettings.isPhotosNotificationsPermissionsSkipped = true
        uploadCancellable = nil
    }
}
