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
import PDUIComponents
import ProtonCoreServices
import ProtonCoreKeymaker
import SwiftUI
import Combine

final class PhotosScenesContainer {
    struct Dependencies {
        let tower: Tower
        let keymaker: Keymaker
        let networkService: PMAPIService
        let backupController: PhotosBackupController
        let settingsController: PhotoBackupSettingsController
        let authorizationController: PhotoLibraryAuthorizationController
        let bootstrapController: PhotosBootstrapController
        let networkConstraintController: PhotoBackupConstraintController
        let backupProgressController: PhotosBackupProgressController
        let processingController: PhotosProcessingController
        let uploader: PhotoUploader
        let quotaStateController: QuotaStateController
        let quotaConstraintController: PhotoBackupConstraintController
        let availableSpaceController: PhotoBackupConstraintController
        let featureFlagController: PhotoBackupConstraintController
        let lockBannerRepository: ScreenLockingBannerRepository
        let failedPhotosResource: DeletedPhotosIdentifierStoreResource
        let backupStateController: LocalPhotosBackupStateController
        let retryTriggerController: PhotoLibraryLoadRetryTriggerController
        let constraintsController: PhotoBackupConstraintsController
        let photoSharesObserver: FetchedResultsControllerObserver<PDCore.Share>
    }
    private let dependencies: Dependencies
    private let rootViewModel: RootViewModel
    private lazy var thumbnailsContainer = ThumbnailsControllersContainer(
        tower: dependencies.tower,
        photoSharesObserver: dependencies.photoSharesObserver
    )

    // We need to share same reference for multiple constructed scenes, but want them released when all screens are dismissed.
    private weak var galleryController: PhotosGalleryController?
    private weak var previewController: PhotosPreviewController?
    private weak var loadController: PhotosPagingLoadController?
    private weak var uploadedPhotosObserver: FetchedResultsSectionsController<Photo>?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        rootViewModel = RootViewModel()
    }

    func makeRootViewController() -> UIViewController {
        let factory = PhotosScenesFactory()
        let coordinator = factory.makeCoordinator(container: self)
        let selectionController = factory.makeSelectionController()
        let photosPagingLoadController = getLoadController()

        let photosRootVM = factory.makeRootViewModel(
            coordinator: coordinator,
            settingsController: dependencies.settingsController,
            authorizationController: dependencies.authorizationController,
            galleryController: getGalleryController(),
            selectionController: selectionController,
            photosPagingLoadController: photosPagingLoadController
        )
        return factory.makeRootPhotosViewController(
            coordinator: coordinator,
            rootViewModel: rootViewModel,
            viewModel: photosRootVM,
            onboardingView: { [unowned self] in
                makeOnboardingView()
            },
            permissionsView: {
                factory.makePermissionsView(coordinator: coordinator)
            },
            galleryView: makeGalleryView(coordinator: coordinator, selectionController: selectionController, photosPagingLoadController: photosPagingLoadController)
        )
    }

    private func makeOnboardingView() -> some View {
        let factory = PhotosScenesFactory()
        return factory.makeOnboardingView(
            settingsController: dependencies.settingsController,
            authorizationController: dependencies.authorizationController,
            bootstrapController: dependencies.bootstrapController
        )
    }

    private func makeGalleryView(
        coordinator: PhotosCoordinator,
        selectionController: PhotosSelectionController,
        photosPagingLoadController: PhotosPagingLoadController
    ) -> some View {
        let factory = PhotosScenesFactory()
        let backupStartController = LocalPhotosBackupStartController(
            settingsController: dependencies.settingsController,
            authorizationController: dependencies.authorizationController,
            photosBootstrapController: dependencies.bootstrapController
        )
        let stateView = factory.makeStateView(
            controller: dependencies.backupStateController,
            coordinator: coordinator,
            constraintsController: dependencies.constraintsController,
            backupStartController: backupStartController,
            settingsController: dependencies.settingsController
        )
        let lockingBannerView = factory.makeLockingBannerView(notifier: dependencies.backupStateController, repository: dependencies.lockBannerRepository)
        return factory.makeGalleryView(
            tower: dependencies.tower,
            coordinator: coordinator,
            galleryController: getGalleryController(),
            thumbnailsContainer: thumbnailsContainer,
            settingsController: dependencies.settingsController,
            loadController: photosPagingLoadController,
            errorControllers: [dependencies.processingController, dependencies.uploader],
            selectionController: selectionController,
            photosObserver: getUploadedPhotosObserver(), 
            photoSharesObserver: dependencies.photoSharesObserver,
            stateView: stateView,
            lockingBannerView: lockingBannerView,
            storageView: factory.makeStorageView(quotaStateController: dependencies.quotaStateController, progressController: dependencies.backupProgressController, coordinator: coordinator)
        )
    }

    func makePreviewController(id: PhotoId) -> UIViewController {
        let dependencies = PhotosPreviewContainer.Dependencies(
            id: id,
            tower: dependencies.tower,
            galleryController: getGalleryController(),
            thumbnailsContainer: thumbnailsContainer
        )
        let container = PhotosPreviewContainer(dependencies: dependencies)
        return container.makeRootViewController(with: id)
    }

    func makeShareViewController(id: PhotoId) -> UIViewController? {
        let factory = PhotosScenesFactory()
        return factory.makeShareViewController(id: id, tower: dependencies.tower, rootViewModel: rootViewModel)
    }

    func makeSubscriptionsViewController() -> UIViewController {
        let dependencies = SubscriptionsContainer.Dependencies(tower: dependencies.tower, keymaker: dependencies.keymaker, networkService: dependencies.networkService)
        let container = SubscriptionsContainer(dependencies: dependencies)
        return container.makeRootViewController()
    }
    
    func makeRetryViewController() -> UIViewController {
        PhotosScenesFactory().makeRetryViewController(
            deletedStoreResource: dependencies.failedPhotosResource, retryTriggerController: dependencies.retryTriggerController
        )
    }

    // MARK: - Cached controllers

    private func getGalleryController() -> PhotosGalleryController {
        let galleryController = galleryController ?? PhotosScenesFactory().makeGalleryController(tower: dependencies.tower, observer: getUploadedPhotosObserver())
        self.galleryController = galleryController
        return galleryController
    }

    private func getPreviewController(id: PhotoId) -> PhotosPreviewController {
        let previewController = previewController ?? PhotosScenesFactory().makePreviewController(galleryController: getGalleryController(), currentId: id)
        self.previewController = previewController
        return previewController
    }

    private func getLoadController() -> PhotosPagingLoadController {
        let loadController = loadController ?? PhotosScenesFactory().makePagingLoadController(
            tower: dependencies.tower,
            bootstrapController: dependencies.bootstrapController,
            networkConstraintController: dependencies.networkConstraintController,
            photoSharesObserver: dependencies.photoSharesObserver
        )
        self.loadController = loadController
        return loadController
    }

    private func getUploadedPhotosObserver() -> FetchedResultsSectionsController<Photo> {
        let uploadedPhotosObserver = uploadedPhotosObserver ?? PhotosScenesFactory().makeUploadedPhotosObserver(tower: dependencies.tower)
        self.uploadedPhotosObserver = uploadedPhotosObserver
        return uploadedPhotosObserver
    }
}
