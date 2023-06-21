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

    func makeCoordinator(container: PhotosScenesContainer) -> PhotosCoordinator {
        PhotosCoordinator(container: container)
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
        authorizationController: PhotoLibraryAuthorizationController,
        galleryController: PhotosGalleryController
    ) -> any PhotosRootViewModelProtocol {
        PhotosRootViewModel(coordinator: coordinator, settingsController: settingsController, authorizationController: authorizationController, galleryController: galleryController)
    }

    func makeOnboardingView(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        bootstrapController: PhotosBootstrapController
    ) -> some View {
        let startController = LocalPhotosBackupStartController(settingsController: settingsController, authorizationController: authorizationController, photosBootstrapController: bootstrapController)
        return PhotosOnboardingView(viewModel: PhotosOnboardingViewModel(startController: startController))
    }

    func makePermissionsView(coordinator: PhotosPermissionsCoordinator) -> some View {
        let viewModel = PhotosPermissionsViewModel(coordinator: coordinator)
        return PhotosPermissionsView(viewModel: viewModel)
    }

    func makeGalleryView(tower: Tower, coordinator: PhotosCoordinator, galleryController: PhotosGalleryController, thumbnailsController: ThumbnailsController, uploadController: PhotosBackupUploadAvailableController, progressController: PhotosBackupProgressController) -> some View {
        PhotosGalleryView(
            viewModel: PhotosGalleryViewModel(galleryController: galleryController, uploadController: uploadController),
            grid: {
                makeGridView(tower: tower, coordinator: coordinator, galleryController: galleryController, thumbnailsController: thumbnailsController)
            },
            placeholder: makeGalleryPlaceholderView,
            state: {
                makeStateView(progressController: progressController)
            }
        )
    }

    private func makeGalleryPlaceholderView() -> some View {
        let viewModel = PhotosGalleryPlaceholderViewModel(timerFactory: MainQueueTimerFactory())
        return PhotosGalleryPlaceholderView(viewModel: viewModel)
    }

    private func makeStateView(progressController: PhotosBackupProgressController) -> some View {
        let controller = LocalPhotosUploadStateController(progressController: progressController)
        let viewModel = PhotosStateViewModel(controller: controller)
        return PhotosStateView(viewModel: viewModel) { items in
            let viewModel = PhotosStateTitlesViewModel(timerFactory: MainQueueTimerFactory(), items: items)
            return PhotosStateTitlesView(viewModel: viewModel)
        }
    }

    private func makeGridView(tower: Tower, coordinator: PhotosCoordinator, galleryController: PhotosGalleryController, thumbnailsController: ThumbnailsController) -> some View {
        let monthFormatter = LocalizedMonthFormatter(dateResource: PlatformDateResource(), dateFormatter: PlatformMonthAndYearFormatter(), monthResource: PlatformMonthResource())
        let viewModel = PhotosGridViewModel(
            controller: galleryController,
            loadController: makePagingLoadController(tower: tower),
            monthFormatter: monthFormatter,
            durationFormatter: LocalizedDurationFormatter()
        )
        return PhotosGridView(viewModel: viewModel) { item in
            makeItemView(item: item, thumbnailsController: thumbnailsController, coordinator: coordinator)
        }
    }

    private func makePagingLoadController(tower: Tower) -> RemotePhotosPagingLoadController {
        let factory = PhotosFactory()
        let observer = factory.makeDevicesObserver(tower: tower)
        let dataSource = PhotosFactory().makeLocalPhotosRootDataSource(observer: observer)
        let filterResource = CoreDataPhotosListFilterResource(storage: tower.storage, managedObjectContext: tower.storage.backgroundContext)
        let listInteractor = PhotosListLoadInteractor(volumeIdDataSource: DatabasePhotosVolumeIdDataSource(deviceDataSource: dataSource), listing: tower.client)
        let listFacadeInteractor = AsyncPhotosListLoadResultInteractor(interactor: listInteractor)
        let metadataInteractor = PhotosMetadataLoadInteractor(shareIdDataSource: DatabasePhotoShareIdDataSource(dataSource: dataSource), listing: tower.client, updateRepository: tower.cloudSlot, filterResource: filterResource)
        let metadataFacadeInteractor = AsyncPhotosMetadataLoadResultInteractor(interactor: metadataInteractor)
        let interactor = RemotePhotosFullLoadInteractor(listInteractor: listFacadeInteractor, metadataInteractor: metadataFacadeInteractor)
        return RemotePhotosPagingLoadController(interactor: interactor)
    }

    private func makeItemView(item: PhotoGridViewItem, thumbnailsController: ThumbnailsController, coordinator: PhotoItemCoordinator) -> some View {
        let id = PhotoId(item.photoId, item.shareId)
        let thumbnailController = LocalThumbnailController(thumbnailsController: thumbnailsController, id: id)
        let viewModel = PhotoItemViewModel(item: item, thumbnailController: thumbnailController, coordinator: coordinator)
        return PhotoItemView(viewModel: viewModel)
    }

    // MARK: - Controllers

    func makeGalleryController(tower: Tower) -> PhotosGalleryController {
        LocalPhotosGalleryController(repository: LocalPhotosRepository(storageManager: tower.storage))
    }

    func makeSmallThumbnailsController(tower: Tower) -> ThumbnailsController {
        let thumbnailLoader = ThumbnailLoaderFactory().makePhotoSmallThumbnailLoader(tower: tower)
        return makeThumbnailsController(tower: tower, filterStrategy: SmallThumbnailFilterStrategy(), thumbnailLoader: thumbnailLoader)
    }

    func makeBigThumbnailsController(tower: Tower) -> ThumbnailsController {
        let thumbnailLoader = ThumbnailLoaderFactory().makePhotoBigThumbnailLoader(tower: tower)
        return makeThumbnailsController(tower: tower, filterStrategy: BigThumbnailFilterStrategy(), thumbnailLoader: thumbnailLoader)
    }

    private func makeThumbnailsController(tower: Tower, filterStrategy: ThumbnailFilterStrategy, thumbnailLoader: ThumbnailLoader) -> ThumbnailsController {
        let managedObjectContext = tower.storage.backgroundContext
        let fetchedResultsController = tower.storage.subscriptionToThumbnails(moc: managedObjectContext)
        let observer = PhotoThumbnailsFetchedObjectsObserver(fetchedResultsController: fetchedResultsController, filterStrategy: filterStrategy)
        let repository = DatabaseThumbnailsRepository(managedObjectContext: managedObjectContext, observer: observer)
        return LocalThumbnailsController(repository: repository, thumbnailLoader: thumbnailLoader)
    }

    func makePreviewController(galleryController: PhotosGalleryController, currentId: PhotoId) -> PhotosPreviewController {
        ListingPhotosPreviewController(controller: galleryController, currentId: currentId)
    }
}
