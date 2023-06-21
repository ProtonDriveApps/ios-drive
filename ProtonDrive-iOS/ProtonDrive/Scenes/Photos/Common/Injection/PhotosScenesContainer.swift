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
import SwiftUI

final class PhotosScenesContainer {
    struct Dependencies {
        let tower: Tower
        let backupController: PhotosBackupController
        let settingsController: PhotoBackupSettingsController
        let authorizationController: PhotoLibraryAuthorizationController
        let bootstrapController: PhotosBootstrapController
        let networkConstraintController: PhotoBackupConstraintController
        let backupProgressController: PhotosBackupProgressController
    }
    private let dependencies: Dependencies

    // We need to share same reference for multiple constructed scenes, but want them released when all screens are dismissed.
    private weak var galleryController: PhotosGalleryController?
    private weak var smallThumbnailsController: ThumbnailsController?
    private weak var previewModeController: PhotosPreviewModeController?
    private weak var previewController: PhotosPreviewController?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func makeRootViewController() -> UIViewController {
        let factory = PhotosScenesFactory()
        let coordinator = factory.makeCoordinator(container: self)
        return factory.makeRootPhotosViewController(
            coordinator: coordinator,
            viewModel: factory.makeRootViewModel(coordinator: coordinator, settingsController: dependencies.settingsController, authorizationController: dependencies.authorizationController, galleryController: getGalleryController()),
            onboardingView: { [unowned self] in
                makeOnboardingView()
            },
            permissionsView: {
                factory.makePermissionsView(coordinator: coordinator)
            },
            galleryView: { [unowned self] in
                makeGalleryView(coordinator: coordinator)
            }
        )
    }

    private func makeOnboardingView() -> some View {
        let factory = PhotosScenesFactory()
        return factory.makeOnboardingView(settingsController: dependencies.settingsController, authorizationController: dependencies.authorizationController, bootstrapController: dependencies.bootstrapController)
    }

    private func makeGalleryView(coordinator: PhotosCoordinator) -> some View {
        let factory = PhotosScenesFactory()
        let uploadController = LocalPhotosBackupUploadAvailableController(backupController: dependencies.backupController, networkConstraintController: dependencies.networkConstraintController)
        return factory.makeGalleryView(tower: dependencies.tower, coordinator: coordinator, galleryController: getGalleryController(), thumbnailsController: getSmallThumbnailsController(), uploadController: uploadController, progressController: dependencies.backupProgressController)
    }

    func makePreviewController(id: PhotoId) -> UIViewController {
        let factory = PhotosScenesFactory()
        let dependencies = PhotosPreviewContainer.Dependencies(
            id: id,
            tower: dependencies.tower,
            galleryController: getGalleryController(),
            smallThumbnailsController: getSmallThumbnailsController(),
            bigThumbnailsController: factory.makeBigThumbnailsController(tower: dependencies.tower)
        )
        let container = PhotosPreviewContainer(dependencies: dependencies)
        return container.makeRootViewController(with: id)
    }

    // MARK: - Cached controllers

    private func getGalleryController() -> PhotosGalleryController {
        let galleryController = galleryController ?? PhotosScenesFactory().makeGalleryController(tower: dependencies.tower)
        self.galleryController = galleryController
        return galleryController
    }

    private func getSmallThumbnailsController() -> ThumbnailsController {
        let smallThumbnailsController = smallThumbnailsController ?? PhotosScenesFactory().makeSmallThumbnailsController(tower: dependencies.tower)
        self.smallThumbnailsController = smallThumbnailsController
        return smallThumbnailsController
    }

    private func getPreviewController(id: PhotoId) -> PhotosPreviewController {
        let previewController = previewController ?? PhotosScenesFactory().makePreviewController(galleryController: getGalleryController(), currentId: id)
        self.previewController = previewController
        return previewController
    }
}
