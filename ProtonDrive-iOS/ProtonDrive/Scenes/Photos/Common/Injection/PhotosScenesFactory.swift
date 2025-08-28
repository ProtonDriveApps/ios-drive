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

import CoreData
import PDCore
import PDCoreIOS
import PDUIComponents
import SwiftUI
import UIKit
import Combine
import PDClient
import PDContacts
import PDPhotos

struct PhotosScenesFactory {

    // MARK: - Views

    func makeCoordinator(container: PhotosScenesContainer) -> PhotosCoordinator {
        PhotosCoordinator(container: container)
    }

    func makeSelectionController() -> PhotosSelectionController {
        LocalPhotosSelectionController()
    }

    // swiftlint:disable:next function_parameter_count
    func makeRootPhotosViewController(
        coordinator: PhotosCoordinator,
        rootViewModel: RootViewModel,
        viewModel: some PhotosRootViewModelProtocol,
        onboardingView: @escaping () -> some View,
        permissionsView: @escaping () -> some View,
        galleryView: some View
    ) -> UIViewController {
        let view = PhotosRootView(viewModel: viewModel, onboarding: onboardingView, permissions: permissionsView, galleryView: galleryView)
        let rootView = RootView(vm: rootViewModel, activeArea: { view })
        let viewController = UIHostingController(rootView: rootView)
        coordinator.rootViewController = viewController
        return viewController
    }

    // swiftlint:disable:next function_parameter_count
    func makeRootViewModel(
        coordinator: PhotosRootCoordinator,
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        galleryController: PhotosGalleryController,
        selectionController: PhotosSelectionController,
        photosPagingLoadController: PhotosPagingLoadController,
        photoUpsellFlowController: PhotoUpsellFlowController?,
        bootstrapController: PhotosBootstrapController
    ) -> any PhotosRootViewModelProtocol {
        PhotosRootViewModel(
            coordinator: coordinator,
            settingsController: settingsController,
            authorizationController: authorizationController,
            galleryController: galleryController,
            selectionController: selectionController,
            photosPagingLoadController: photosPagingLoadController,
            photoUpsellFlowController: photoUpsellFlowController,
            bootstrapController: bootstrapController
        )
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

    // swiftlint:disable:next function_parameter_count
    func makeGalleryView(
        tower: Tower,
        coordinator: PhotosCoordinator,
        galleryController: PhotosGalleryController,
        thumbnailsContainer: ThumbnailsControllersContainer,
        settingsController: PhotoBackupSettingsController,
        loadController: PhotosPagingLoadController,
        errorControllers: [ErrorController],
        selectionController: PhotosSelectionController,
        photosObserver: FetchedResultsSectionsController<PDCore.Photo>,
        rootFolderRepository: PhotosRootFolderRepository,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        featureFlagsController: FeatureFlagsControllerProtocol,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>,
        stateView: some View,
        lockingBannerView: some View,
        storageView: some View,
        migrationView: some View
    ) -> some View {
        let errorController = CompoundErrorController(controllers: errorControllers)
        let viewModel = PhotosGalleryViewModel(
            galleryController: galleryController,
            settingsController: settingsController,
            errorController: errorController,
            featureFlagsController: featureFlagsController
        )
        return PhotosGalleryView(
            viewModel: viewModel,
            grid: {
                makeGridView(
                    tower: tower,
                    coordinator: coordinator,
                    galleryController: galleryController,
                    thumbnailsContainer: thumbnailsContainer,
                    loadController: loadController,
                    selectionController: selectionController,
                    photosObserver: photosObserver,
                    rootFolderRepository: rootFolderRepository,
                    photosManagedObjectContext: photosManagedObjectContext,
                    photoUploadedNotifier: photoUploadedNotifier,
                    featureFlagsController: featureFlagsController,
                    scrollToTopPublisher: scrollToTopPublisher
                )
            },
            placeholder: makeGalleryPlaceholderView,
            stateView: stateView,
            lockingBannerView: lockingBannerView,
            storageView: storageView,
            migrationView: migrationView
        )
    }

    private func makeGalleryPlaceholderView() -> some View {
        let viewModel = PhotosGalleryPlaceholderViewModel(timerFactory: MainQueueTimerFactory())
        return PhotosGalleryPlaceholderView(viewModel: viewModel)
    }

    func makeStateView(
        controller: LocalPhotosBackupStateController,
        coordinator: PhotosCoordinator,
        constraintsController: PhotoBackupConstraintsController,
        backupStartController: PhotosBackupStartController,
        settingsController: PhotoBackupSettingsController
    ) -> some View {
        let viewModel = PhotosStateViewModel(
            controller: controller,
            coordinator: coordinator,
            remainingItemsStrategy: RoundingPhotosRemainingItemsStrategy(),
            backupStartController: backupStartController,
            settingsController: settingsController,
            messageHandler: UserMessageHandler()
        )
        let titlesViewModel = PhotosStateTitlesViewModel(timerFactory: MainQueueTimerFactory())
        return PhotosStateView(viewModel: viewModel, title: { items in
            titlesViewModel.set(items)
            return PhotosStateTitlesView(viewModel: titlesViewModel)
        }, additionalView: {
//            #if HAS_QA_FEATURES
//            let viewModel = ConcretePhotosStateAdditionalInfoViewModel(constraintsController: constraintsController)
//            return PhotosStateAdditionalInfoView(viewModel: viewModel).any()
//            #else
            return nil
//            #endif
        })
    }

    func makeStorageView(quotaStateController: QuotaStateController, progressController: PhotosBackupProgressController, coordinator: PhotosStorageCoordinator) -> some View {
        let viewModel = PhotosStorageViewModel(quotaStateController: quotaStateController, progressController: progressController, dataFactory: LocalizedPhotosStorageViewDataFactory(), coordinator: coordinator)
        return PhotosStorageView(viewModel: viewModel)
    }
    
    // swiftlint:disable:next function_parameter_count
    func makeGridView(
        tower: Tower, 
        coordinator: PhotosCoordinator,
        galleryController: PhotosGalleryController,
        thumbnailsContainer: ThumbnailsControllersContainer,
        loadController: PhotosPagingLoadController,
        selectionController: PhotosSelectionController,
        photosObserver: FetchedResultsSectionsController<PDCore.Photo>,
        rootFolderRepository: PhotosRootFolderRepository,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        featureFlagsController: FeatureFlagsControllerProtocol,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>
    ) -> some View {
        let offlineAvailableController = UpdatingOfflineAvailableController(resource: LocalOfflineAvailableResource(tower: tower, downloader: tower.downloader, storage: tower.storage, managedObjectContext: tower.storage.photosSecondaryBackgroundContext))

        let monthFormatter = LocalizedMonthFormatter(dateResource: PlatformCurrentDateResource(), dateFormatter: PlatformMonthAndYearFormatter(), monthResource: PlatformMonthResource())
        let viewModel = PhotosGridViewModel(
            controller: galleryController,
            loadController: loadController,
            monthFormatter: monthFormatter,
            scrollToTopPublisher: scrollToTopPublisher
        )
        let infosController = ConcretePhotoAdditionalInfosController(repository: CoreDataPhotoAdditionalInfoRepository(observer: photosObserver))
        let actionView = makeActionView(
            tower: tower,
            selectionController: selectionController,
            coordinator: coordinator,
            offlineAvailableController: offlineAvailableController,
            rootFolderRepository: rootFolderRepository,
            photosManagedObjectContext: photosManagedObjectContext,
            photoUploadedNotifier: photoUploadedNotifier, 
            featureFlagsController: featureFlagsController
        )
        let itemViewModelFactory = CachingPhotoItemViewModelFactory { item in
            makeItemViewModel(item: item, thumbnailsContainer: thumbnailsContainer, coordinator: coordinator, selectionController: selectionController, infosController: infosController, loadController: loadController, featureFlagsController: featureFlagsController)
        }
        return PhotosGridView(viewModel: viewModel, actionView: actionView) { item, accessibilityIndex in
            return PhotoItemWrapperView {
                let viewModel = itemViewModelFactory.makeViewModel(for: item)
                return PhotoItemView(viewModel: viewModel, accessibilityIndex: accessibilityIndex)
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func makeActionView(
        tower: Tower,
        selectionController: PhotosSelectionController,
        coordinator: PhotosCoordinator,
        offlineAvailableController: OfflineAvailableController,
        rootFolderRepository: PhotosRootFolderRepository,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) -> some View {
        let trashController = makeTrashController(tower: tower, rootFolderRepository: rootFolderRepository)
        let fileContentController = makeFileContentController(
            tower: tower,
            moc: photosManagedObjectContext,
            photoUploadedNotifier: photoUploadedNotifier
        )
        let viewModel = PhotosActionViewModel(trashController: trashController, coordinator: coordinator, selectionController: selectionController, fileContentController: fileContentController, offlineAvailableController: offlineAvailableController, featureFlagsController: featureFlagsController)
        return PhotosActionView(viewModel: viewModel)
    }

    private func makeTrashController(tower: Tower, rootFolderRepository: PhotosRootFolderRepository) -> PhotosTrashController {
        let remoteRepository = makeRemoteTrashRepository(tower: tower, rootFolderRepository: rootFolderRepository)
        let localRepository = DatabasePhotosTrashRepository(storageManager: tower.storage)
        let trashInteractor = PhotosTrashInteractor(remoteRepository: remoteRepository, localRepository: localRepository)
        let trashFacade = AsyncPhotosTrashFacade(interactor: trashInteractor)
        return LocalPhotosTrashController(facade: trashFacade)
    }

    private func makeRemoteTrashRepository(tower: Tower, rootFolderRepository: PhotosRootFolderRepository) -> RemotePhotosTrashRepository {
        let rootIdDataSource = DatabasePhotosFolderIdDataSource(repository: rootFolderRepository)
        return BackendRemotePhotosTrashRepository(client: tower.client, rootIdDataSource: rootIdDataSource)
    }

    // swiftlint:disable:next function_parameter_count
    private func makeItemViewModel(item: PhotoGridViewItem, thumbnailsContainer: ThumbnailsControllersContainer, coordinator: PhotoItemCoordinator, selectionController: PhotosSelectionController, infosController: PhotoAdditionalInfosController, loadController: PhotosPagingLoadController, featureFlagsController: FeatureFlagsControllerProtocol) -> PhotoItemViewModel {
        let id = PhotoId(id: item.photoId, volumeID: item.volumeId)
        let infoController = ConcretePhotoAdditionalInfoController(id: id, controller: infosController)
        let thumbnailController = thumbnailsContainer.makeSmallThumbnailController(id: id)
        let viewModel = PhotoItemViewModel(item: item, thumbnailController: thumbnailController, coordinator: coordinator, selectionController: selectionController, infoController: infoController, durationFormatter: LocalizedDurationFormatter(), debounceResource: CommonLoopDebounceResource(), loadController: loadController, featureFlagsController: featureFlagsController)
        return viewModel
    }

    func makeShareViewController(id: PhotoId, tower: Tower, rootViewModel: RootViewModel) -> UIViewController? {
        guard let view = try? ShareLinkIdFlowCoordinator().start((id, tower, rootViewModel)) else {
            return nil
        }
        return UIHostingController(rootView: view)
    }

    // swiftlint:disable:next function_parameter_count
    func makeNewShareViewController(
        identifier: PhotoId,
        tower: Tower,
        storage: StorageManager,
        contactsManager: ContactsManagerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol,
        rootViewController: UIViewController
    ) -> SharingStartCoordinator? {

        let photo = storage.mainContext.performAndWait {
            let photo: PDCore.Photo? = PDCore.Photo.fetch(identifier: identifier, in: storage.mainContext)
            return photo
        }

        guard let photo else {
            Log.error("Photo: \(identifier) could not be found.", error: nil, domain: .photosProcessing)
            return nil
        }

        let dependencies = SharingMemberStartDependencies(
            tower: tower,
            contactsManager: contactsManager,
            featureFlagsController: featureFlagsController,
            invitationResultController: nil,
            rootViewController: rootViewController
        )
        let sharingMemberFactory = SharingMemberStartFactory()
        return sharingMemberFactory.makeCoordinator(
            dependencies: dependencies,
            node: photo
        )
    }

    func makeRetryViewController(deletedStoreResource: DeletedPhotosIdentifierStoreResource, retryTriggerController: PhotoLibraryLoadRetryTriggerController) -> UIViewController {
        let strategyFactory = RetryUnwrappingStrategyFactory()
        let previewProvider = ConcretePhotoLibraryPreviewResource.makeApplePhotosPreviewResource()
        let interactor = PhotosRetryInteractor(deletedStoreResource: deletedStoreResource, previewProvider: previewProvider, retryTriggerController: retryTriggerController)
        let viewModel = PhotosRetryViewModel(interactor: interactor, nameUnwrappingStrategy: strategyFactory.makeItemNameUnwrappingStrategy(), imageUnwrappingStrategy: strategyFactory.makeImageUnwrappingStrategy())
        let view = NavigationView { PhotosRetryView(viewModel: viewModel) }
        return UIHostingController(rootView: view)
    }

    func makeMigrationView(
        migrationController: PhotoVolumeMigrationControllerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) -> some View {
        let viewModel = PhotosMigrationBannerViewModel(
            migrationController: migrationController,
            featureFlagsController: featureFlagsController
        )
        return MigrationBannerView(viewModel: viewModel)
    }

    // MARK: - Controllers

    func makeGalleryController(tower: Tower, observer: FetchedResultsSectionsController<PDCore.Photo>) -> PhotosGalleryController {
        let managedObjectContext = observer.managedObjectContext
        let offlineAvailableResource = LocalOfflineAvailableResource(tower: tower, downloader: tower.downloader, storage: tower.storage, managedObjectContext: managedObjectContext)
        let repository = LocalPhotosRepository(observer: observer, mimeTypeResource: CachingMimeTypeResource(), offlineAvailableResource: offlineAvailableResource)
        return LocalPhotosGalleryController(repository: repository)
    }

    func makePreviewController(galleryController: PhotosGalleryController, currentId: PhotoId) -> PhotosPreviewController {
        ListingPhotosPreviewController(controller: galleryController, currentId: currentId)
    }

    func makeFileContentController(
        tower: Tower,
        moc: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier
    ) -> FileContentController {
        let contentResource = DecryptedPhotoContentResource(
            managedObjectContext: moc,
            downloader: tower.downloader,
            fetchResource: PhotoFetchResource(storage: tower.storage),
            validationResource: PhotoURLValidationResource(),
            photoUploadedNotifier: photoUploadedNotifier
        )
        return LocalFileContentController(resource: contentResource, storageResource: LocalFileStorageResource())
    }

    func makeUploadedPhotosObserver(tower: Tower) -> FetchedResultsSectionsController<PDCore.Photo> {
        // VolumeID fetched at this point to avoid potential locks
        let volumeID = tower.storage.mainContext.performAndWait { (try? tower.storage.getMyVolumeId(in: tower.storage.mainContext)) ?? "" }
        let managedObjectContext = tower.storage.photosSecondaryBackgroundContext
        let fetchedController = tower.storage.subscriptionToMyPrimaryUploadedPhotos(volumeID: volumeID, moc: managedObjectContext)
        return FetchedResultsSectionsController(controller: fetchedController)
    }
}
