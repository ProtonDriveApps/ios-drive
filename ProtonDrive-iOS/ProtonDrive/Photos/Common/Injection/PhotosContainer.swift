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
    private let constraintsController: PhotoBackupConstraintsController
    private let loadController: PhotoLibraryLoadController
    private let assetsController: PhotoAssetsController
    let operationInteractor: OperationInteractor
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let bootstrapController: PhotosBootstrapController

    // We need to keep same reference for every constructed scene, but want them released when all screens are dismissed.
    private weak var galleryController: PhotosGalleryController?
    private weak var smallThumbnailsController: ThumbnailsController?
    private weak var previewModeController: PhotosPreviewModeController?
    private weak var detailController: PhotoPreviewDetailController?
    private weak var previewController: PhotosPreviewController?

    init(tower: Tower) {
        self.tower = tower
        let factory = PhotosFactory()
        let queueResource = factory.makeAssetsQueueResource()
        let assetsInteractor = factory.makeAssetsInteractor(queueResource: queueResource, tower: tower)
        operationInteractor = factory.makeAssetsOperationInteractor(queueResource: queueResource)
        let settingsController = factory.makeSettingsController(localSettings: tower.localSettings)
        let authorizationController = factory.makeAuthorizationController()
        let bootstrapController = factory.makePhotosBootstrapController(tower: tower)
        let backupController = factory.makeBackupController(settingsController: settingsController, authorizationController: authorizationController, bootstrapController: bootstrapController)
        let constraintsController = factory.makeConstraintsController(backupController: backupController, settingsController: settingsController)
        loadController = factory.makeLoadController(backupController: backupController, assetsInteractor: assetsInteractor, tower: tower)
        assetsController = factory.makeAssetsController(constraintsController: constraintsController, interactor: assetsInteractor)
        self.constraintsController = constraintsController
        self.backupController = backupController
        self.authorizationController = authorizationController
        self.settingsController = settingsController
        self.bootstrapController = bootstrapController
    }

    // MARK: Views

    func makeRootViewController() -> UIViewController {
        let factory = PhotosScenesFactory()
        let coordinator = factory.makeCoordinator(container: self)
        return factory.makeRootPhotosViewController(
            coordinator: coordinator,
            viewModel: factory.makeRootViewModel(coordinator: coordinator, settingsController: settingsController, authorizationController: authorizationController),
            onboardingView: { [unowned self] in
                factory.makeOnboardingView(settingsController: settingsController, authorizationController: authorizationController, bootstrapController: bootstrapController)
            },
            permissionsView: {
                factory.makePermissionsView(coordinator: coordinator)
            },
            galleryView: { [unowned self] in
                factory.makeGalleryView(tower: tower, coordinator: coordinator, galleryController: getGalleryController(), thumbnailsController: getSmallThumbnailsController())
            }
        )
    }

    func makePreviewViewController(with id: PhotoId) -> UIViewController {
        let factory = PhotosScenesFactory()
        return factory.makePreviewViewController(previewController: getPreviewController(id: id), galleryController: getGalleryController(), container: self, modeController: getPreviewModeController(), detailController: getDetailController())
    }

    func makePreviewDetailViewController(with id: PhotoId) -> UIViewController {
        let factory = PhotosScenesFactory()
        return factory.makeDetailViewController(id: id, thumbnailsController: getSmallThumbnailsController(), modeController: getPreviewModeController(), previewController: getPreviewController(id: id), detailController: getDetailController())
    }

    // MARK: - Cached controllers

    private func getGalleryController() -> PhotosGalleryController {
        let galleryController = galleryController ?? PhotosScenesFactory().makeGalleryController(tower: tower)
        self.galleryController = galleryController
        return galleryController
    }

    private func getSmallThumbnailsController() -> ThumbnailsController {
        let smallThumbnailsController = smallThumbnailsController ?? PhotosScenesFactory().makeSmallThumbnailsController(tower: tower)
        self.smallThumbnailsController = smallThumbnailsController
        return smallThumbnailsController
    }

    private func getPreviewController(id: PhotoId) -> PhotosPreviewController {
        let previewController = previewController ?? PhotosScenesFactory().makePreviewController(galleryController: getGalleryController(), currentId: id)
        self.previewController = previewController
        return previewController
    }

    private func getPreviewModeController() -> PhotosPreviewModeController {
        let previewModeController = previewModeController ?? PhotosScenesFactory().makePreviewModeController()
        self.previewModeController = previewModeController
        return previewModeController
    }

    private func getDetailController() -> PhotoPreviewDetailController {
        let detailController = detailController ?? PhotosScenesFactory().makeDetailController(tower: tower)
        self.detailController = detailController
        return detailController
    }
}
