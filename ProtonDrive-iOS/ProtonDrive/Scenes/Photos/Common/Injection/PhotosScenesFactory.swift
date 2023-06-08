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
import SwiftUI
import UIKit

struct PhotosScenesFactory {

    // MARK: - Views

    func makeCoordinator(container: PhotosContainer) -> PhotosCoordinator {
        let coordinator = PhotosCoordinator()
        coordinator.container = container
        return coordinator
    }
    
    func makeRootPhotosViewController(
        coordinator: PhotosCoordinator,
        viewModel: some PhotosRootViewModelProtocol,
        onboardingView: @escaping () -> some View,
        permissionsView: @escaping () -> some View,
        galleryView: @escaping () -> some View
    ) -> UIViewController {
        let view = PhotosRootView(viewModel: viewModel, onboarding: onboardingView, permissions: permissionsView, gallery: galleryView)
        let viewController = UIHostingController(rootView: view)
        coordinator.rootViewController = viewController
        return UINavigationController(rootViewController: viewController)
    }

    func makeRootViewModel(
        coordinator: PhotosRootCoordinator,
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController
    ) -> any PhotosRootViewModelProtocol {
        PhotosRootViewModel(coordinator: coordinator, settingsController: settingsController, authorizationController: authorizationController)
    }

    func makeOnboardingView(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        bootstrapController: PhotosBootstrapController
    ) -> some View {
        PhotosOnboardingView(viewModel: PhotosOnboardingViewModel(settingsController: settingsController, authorizationController: authorizationController, photosBootstrapController: bootstrapController))
    }

    func makePermissionsView(coordinator: PhotosPermissionsCoordinator) -> some View {
        let viewModel = PhotosPermissionsViewModel(coordinator: coordinator)
        return PhotosPermissionsView(viewModel: viewModel)
    }

    func makeGalleryView(tower: Tower, coordinator: PhotosCoordinator, galleryController: PhotosGalleryController, thumbnailsController: ThumbnailsController) -> some View {
        PhotosGalleryView(viewModel: PhotosGalleryViewModel(), grid: {
            makeGridView(tower: tower, coordinator: coordinator, galleryController: galleryController, thumbnailsController: thumbnailsController)
        })
    }

    private func makeGridView(tower: Tower, coordinator: PhotosCoordinator, galleryController: PhotosGalleryController, thumbnailsController: ThumbnailsController) -> some View {
        let monthFormatter = LocalizedMonthFormatter(dateResource: PlatformDateResource(), dateFormatter: PlatformMonthAndYearFormatter(), monthResource: PlatformMonthResource())
        let viewModel = PhotosGridViewModel(
            controller: galleryController,
            monthFormatter: monthFormatter,
            durationFormatter: LocalizedDurationFormatter()
        )
        return PhotosGridView(viewModel: viewModel) { item in
            makeItemView(item: item, thumbnailsController: thumbnailsController, coordinator: coordinator)
        }
    }

    private func makeItemView(item: PhotoGridViewItem, thumbnailsController: ThumbnailsController, coordinator: PhotoItemCoordinator) -> some View {
        let id = PhotoId(item.photoId, item.shareId)
        let thumbnailController = LocalThumbnailController(thumbnailsController: thumbnailsController, id: id)
        let viewModel = PhotoItemViewModel(item: item, thumbnailController: thumbnailController, coordinator: coordinator)
        return PhotoItemView(viewModel: viewModel)
    }

    func makePreviewViewController(
        previewController: PhotosPreviewController,
        galleryController: PhotosGalleryController,
        container: PhotosContainer,
        modeController: PhotosPreviewModeController,
        detailController: PhotoPreviewDetailController
    ) -> UIViewController {
        let coordinator = PhotosPreviewCoordinator()
        let viewModel = PhotosPreviewViewModel(controller: previewController, coordinator: coordinator, modeController: modeController, detailController: detailController)
        let viewController = PhotosPreviewViewController(viewModel: viewModel, factory: coordinator)
        coordinator.rootViewController = viewController
        coordinator.container = container
        return UINavigationController(rootViewController: viewController)
    }

    func makeDetailViewController(
        id: PhotoId,
        thumbnailsController: ThumbnailsController,
        modeController: PhotosPreviewModeController,
        previewController: PhotosPreviewController,
        detailController: PhotoPreviewDetailController
    ) -> UIViewController {
        let fullPreviewController = DummyPhotoFullPreviewController()
        let thumbnailController = LocalThumbnailController(thumbnailsController: thumbnailsController, id: id)
        let viewModel = PhotoPreviewDetailViewModel(thumbnailController: thumbnailController, modeController: modeController, previewController: previewController, detailController: detailController, fullPreviewController: fullPreviewController, id: id)
        return PhotoPreviewDetailViewController(viewModel: viewModel)
    }

    // MARK: - Controllers

    func makeGalleryController(tower: Tower) -> PhotosGalleryController {
        LocalPhotosGalleryController(repository: LocalPhotosRepository(storageManager: tower.storage))
    }

    func makeSmallThumbnailsController(tower: Tower) -> ThumbnailsController {
        makeThumbnailsController(tower: tower, filterStrategy: SmallThumbnailFilterStrategy())
    }

    private func makeThumbnailsController(tower: Tower, filterStrategy: ThumbnailFilterStrategy) -> ThumbnailsController {
        let managedObjectContext = tower.storage.backgroundContext
        let fetchedResultsController = tower.storage.subscriptionToThumbnails(moc: managedObjectContext)
        let observer = PhotoThumbnailsFetchedObjectsObserver(fetchedResultsController: fetchedResultsController, filterStrategy: filterStrategy)
        let repository = DatabaseThumbnailsRepository(managedObjectContext: managedObjectContext, observer: observer)
        return LocalThumbnailsController(repository: repository, thumbnailLoader: tower)
    }

    func makePreviewModeController() -> PhotosPreviewModeController {
        GalleryPhotosPreviewModeController()
    }

    func makeDetailController(tower: Tower) -> PhotoPreviewDetailController {
        LocalPhotoPreviewDetailController(repository: DatabasePhotoInfoRepository(storage: tower.storage))
    }

    func makePreviewController(galleryController: PhotosGalleryController, currentId: PhotoId) -> PhotosPreviewController {
        ListingPhotosPreviewController(controller: galleryController, currentId: currentId)
    }
}
