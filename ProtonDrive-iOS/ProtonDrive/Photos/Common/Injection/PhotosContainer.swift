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
import UIKit

final class PhotosContainer {
    private let tower: Tower
    private let backupController: PhotosBackupController
    private let networkConstraintController: PhotoBackupConstraintController
    private let constraintsController: PhotoBackupConstraintsController
    private let loadController: PhotoLibraryLoadController
    private let assetsController: PhotoAssetsController
    let operationInteractor: OperationInteractor
    private let uploader: PhotoUploader
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let bootstrapController: PhotosBootstrapController
    private let backupProgressController: PhotosBackupProgressController
    // Child containers
    lazy var settingsContainer = makeSettingsContainer()

    init(tower: Tower) {
        self.tower = tower
        let factory = PhotosFactory()
        let devicesObserver = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPhotoDevices())
        let queueResource = factory.makeAssetsQueueResource()
        let progressRepository = factory.makeBackupProgressRepository()
        backupProgressController = factory.makeBackupProgressController(tower: tower, repository: progressRepository)
        let assetsInteractor = factory.makeAssetsInteractor(observer: devicesObserver, queueResource: queueResource, tower: tower, progressRepository: progressRepository)
        operationInteractor = factory.makeAssetsOperationInteractor(queueResource: queueResource)
        let settingsController = factory.makeSettingsController(localSettings: tower.localSettings)
        let authorizationController = factory.makeAuthorizationController()
        let bootstrapController = factory.makePhotosBootstrapController(tower: tower)
        let backupController = factory.makeBackupController(settingsController: settingsController, authorizationController: authorizationController, bootstrapController: bootstrapController)
        let networkConstraintController = factory.makeNetworkConstraintController(backupController: backupController, settingsController: settingsController)
        self.networkConstraintController = networkConstraintController
        let constraintsController = factory.makeConstraintsController(backupController: backupController, settingsController: settingsController, networkConstraintController: networkConstraintController)
        loadController = factory.makeLoadController(backupController: backupController, assetsInteractor: assetsInteractor, tower: tower, progressRepository: progressRepository)
        assetsController = factory.makeAssetsController(constraintsController: constraintsController, interactor: assetsInteractor)
        self.constraintsController = constraintsController
        self.backupController = backupController
        self.authorizationController = authorizationController
        self.settingsController = settingsController
        self.bootstrapController = bootstrapController
        self.uploader = factory.makePhotoUploader(tower: tower)
    }

    private func makeSettingsContainer() -> PhotosSettingsContainer {
        let dependencies = PhotosSettingsContainer.Dependencies(
            settingsController: settingsController,
            authorizationController: authorizationController,
            bootstrapController: bootstrapController
        )
        return PhotosSettingsContainer(dependencies: dependencies)
    }

    // MARK: Views

    func makeRootViewController() -> UIViewController {
        let dependencies = PhotosScenesContainer.Dependencies(
            tower: tower,
            backupController: backupController,
            settingsController: settingsController,
            authorizationController: authorizationController,
            bootstrapController: bootstrapController,
            networkConstraintController: networkConstraintController,
            backupProgressController: backupProgressController
        )
        let container = PhotosScenesContainer(dependencies: dependencies)
        return container.makeRootViewController()
    }
}
