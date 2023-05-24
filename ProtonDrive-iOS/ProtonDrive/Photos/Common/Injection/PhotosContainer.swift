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

import PDCore

final class PhotosContainer {
    private let backupController: PhotosBackupController
    private let constraintsController: PhotoBackupConstraintsController
    private let loadController: PhotoLibraryLoadController
    private let assetsController: PhotoAssetsController
    let operationInteractor: OperationInteractor
    let settingsController: PhotoBackupSettingsController
    let authorizationController: PhotoLibraryAuthorizationController

    init(localSettings: LocalSettings) {
        let factory = PhotosFactory()
        let queueResource = factory.makeAssetsQueueResource()
        let assetsInteractor = factory.makeAssetsInteractor(queueResource: queueResource)
        operationInteractor = factory.makeAssetsOperationInteractor(queueResource: queueResource)
        let settingsController = factory.makeSettingsController(localSettings: localSettings)
        let authorizationController = factory.makeAuthorizationController()
        let backupController = factory.makeBackupController(settingsController: settingsController, authorizationController: authorizationController)
        let constraintsController = factory.makeConstraintsController(backupController: backupController)
        loadController = factory.makeLoadController(backupController: backupController, assetsInteractor: assetsInteractor)
        assetsController = factory.makeAssetsController(constraintsController: constraintsController, interactor: assetsInteractor)
        self.constraintsController = constraintsController
        self.backupController = backupController
        self.authorizationController = authorizationController
        self.settingsController = settingsController
    }
}