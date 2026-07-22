// Copyright (c) 2025 Proton AG
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

struct GalleryScenesFactory {

    func makeCoordinator(container: GallerySceneContainer) -> GalleryCoordinator {
        GalleryCoordinator(container: container)
    }

    // swiftlint:disable:next function_parameter_count
    func makeRootView(
        configuration: PhotosRootConfiguration,
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        initialLoadController: PhotosListFetchingStatusControllerProtocol,
        photoUpsellFlowController: PhotoUpsellFlowController?,
        managedObjectContext: NSManagedObjectContext,
        volumeId: VolumeID,
        screenLockController: ScreenLockController,
        onboardingView: @escaping () -> some View,
        permissionsView: @escaping () -> some View,
        galleryView: some View
    ) -> some View {
        let viewModel = makeRootViewModel(
            configuration: configuration,
            settingsController: settingsController,
            authorizationController: authorizationController,
            listController: listController,
            fetchingController: fetchingController,
            initialLoadController: initialLoadController,
            photoUpsellFlowController: photoUpsellFlowController,
            managedObjectContext: managedObjectContext,
            volumeId: volumeId,
            screenLockController: screenLockController
        )
        return GalleryRootView(
            viewModel: viewModel,
            onboarding: onboardingView,
            permissions: permissionsView,
            galleryView: galleryView
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func makeRootViewModel(
        configuration: PhotosRootConfiguration,
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        initialLoadController: PhotosListFetchingStatusControllerProtocol,
        photoUpsellFlowController: PhotoUpsellFlowController?,
        managedObjectContext: NSManagedObjectContext,
        volumeId: VolumeID,
        screenLockController: ScreenLockController
    ) -> GalleryRootViewModel {
        GalleryRootViewModel(
            configuration: configuration,
            settingsController: settingsController,
            authorizationController: authorizationController,
            ownPhotosController: makeOwnPhotosController(managedObjectContext: managedObjectContext, volumeId: volumeId),
            fetchingController: fetchingController,
            fetchingStatusController: initialLoadController,
            photoUpsellFlowController: photoUpsellFlowController,
            screenLockController: screenLockController
        )
    }

    private func makeOwnPhotosController(
        managedObjectContext: NSManagedObjectContext,
        volumeId: VolumeID
    ) -> OwnPhotosControllerProtocol {
        let observer = PhotosListObserverFactory().makeSingleSectionListingObserver(
            managedObjectContext: managedObjectContext,
            volumeId: volumeId
        )
        let repository = OwnPhotosRepository(
            observer: observer,
            managedObjectContext: managedObjectContext
        )
        return OwnPhotosController(repository: repository)
    }

    func makeOnboardingView(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController
    ) -> some View {
        let startController = SimplePhotosBackupStartController(settingsController: settingsController, authorizationController: authorizationController)
        return PhotosOnboardingView(viewModel: PhotosOnboardingViewModel(startController: startController))
    }

    func makePermissionsView(coordinator: GalleryCoordinator) -> some View {
        let viewModel = PhotosPermissionsViewModel(coordinator: coordinator)
        return PhotosPermissionsView(viewModel: viewModel)
    }

    // swiftlint:disable:next function_parameter_count
    func makeGalleryView(
        tower: Tower,
        coordinator: GalleryCoordinator,
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        thumbnailsContainer: ThumbnailsControllersContainer,
        settingsController: PhotoBackupSettingsController,
        errorControllers: [ErrorController],
        selectionController: PhotosSelectionController,
        rootFolderRepository: PhotosRootFolderRepository,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        featureFlagsController: FeatureFlagsControllerProtocol,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>,
        metadataController: MetadataControllerProtocol,
        configuration: PhotosRootConfiguration,
        offlineAvailableResource: OfflineAvailableResource,
        tagsController: GalleryTagsControllerProtocol,
        infosController: PhotoAdditionalInfosController,
        remoteAlbumFetchController: RemoteAlbumFetchControllerProtocol,
        streamConfiguration: PhotoStreamConfiguration,
        scrollerController: GridScrollerControllerProtocol,
        itemsViewModelsCache: PhotoItemViewModelsCache,
        bannersView: some View,
        tagsView: some View,
        scrollerView: some View
    ) -> some View {
        let errorController = CompoundErrorController(controllers: errorControllers)
        let viewModel = PhotosGalleryViewModel(
            listController: listController,
            fetchingController: fetchingController,
            fetchingStatusController: PhotosListFetchingStatusController(fetchingController: fetchingController),
            errorController: errorController,
            configuration: configuration,
            tagsController: tagsController,
            streamConfiguration: streamConfiguration
        )
        let itemViewModelFactory = CachingPhotoItemViewModelFactory(cache: itemsViewModelsCache) { item in
            makeItemViewModel(item: item, thumbnailsContainer: thumbnailsContainer, coordinator: coordinator, selectionController: selectionController, infosController: infosController, featureFlagsController: featureFlagsController, fetchingController: fetchingController, metadataController: metadataController)
        }
        return PhotosGalleryView(
            viewModel: viewModel,
            grid: { bannersView in
                makeGridView(
                    tower: tower,
                    coordinator: coordinator,
                    listController: listController,
                    thumbnailsContainer: thumbnailsContainer,
                    fetchingController: fetchingController,
                    selectionController: selectionController,
                    rootFolderRepository: rootFolderRepository,
                    photosManagedObjectContext: photosManagedObjectContext,
                    photoUploadedNotifier: photoUploadedNotifier,
                    featureFlagsController: featureFlagsController,
                    scrollToTopPublisher: scrollToTopPublisher,
                    metadataController: metadataController,
                    configuration: configuration,
                    offlineAvailableResource: offlineAvailableResource,
                    infosController: infosController,
                    remoteAlbumFetchController: remoteAlbumFetchController,
                    streamConfiguration: streamConfiguration,
                    scrollerController: scrollerController,
                    bannersView: bannersView,
                    scrollerView: scrollerView,
                    itemViewModelFactory: itemViewModelFactory
                )
            },
            placeholder: makeGalleryPlaceholderView,
            tagsView: tagsView,
            bannersView: bannersView
        )
    }

    private func makeGalleryPlaceholderView(tag: PhotoTag?) -> some View {
        let viewModel = PhotosGalleryPlaceholderViewModel(timerFactory: MainQueueTimerFactory(), tag: tag)
        return PhotosGalleryPlaceholderView(viewModel: viewModel)
    }

    // swiftlint:disable:next function_parameter_count
    func makeStateView(
        controller: PhotosBackupStateController,
        coordinator: GalleryCoordinator,
        constraintsController: PhotoBackupConstraintsController,
        backupStartController: PhotosBackupStartController,
        settingsController: PhotoBackupSettingsController,
        userMessageHandler: UserMessageHandlerProtocol
    ) -> some View {
        let viewModel = PhotosStateViewModel(
            controller: controller,
            coordinator: coordinator,
            remainingItemsStrategy: RoundingPhotosRemainingItemsStrategy(),
            backupStartController: backupStartController,
            settingsController: settingsController,
            messageHandler: userMessageHandler
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
//
    func makeStorageView(quotaStateController: QuotaStateController, progressController: PhotosBackupProgressController, coordinator: PhotosStorageCoordinator) -> some View {
        let viewModel = PhotosStorageViewModel(quotaStateController: quotaStateController, progressController: progressController, dataFactory: LocalizedPhotosStorageViewDataFactory(), coordinator: coordinator)
        return PhotosStorageView(viewModel: viewModel)
    }

    func makeBannersView(
        stateView: some View,
        lockingBannerView: some View,
        storageView: some View
    ) -> some View {
        return GalleryBannersView(
            stateView: stateView,
            lockingBannerView: lockingBannerView,
            storageView: storageView
        )
    }

    func makeScrollerView(scrollerController: GridScrollerControllerProtocol) -> some View {
        let viewModel = GridScrollerViewModel(
            controller: scrollerController,
            debounceResource: CommonLoopDebounceResource(),
            dateFormatter: PlatformMonthAndYearFormatter()
        )
        return GridScrollerView(viewModel: viewModel)
    }

    // swiftlint:disable:next function_parameter_count
    func makeGridView(
        tower: Tower,
        coordinator: GalleryCoordinator,
        listController: PhotosListControllerProtocol,
        thumbnailsContainer: ThumbnailsControllersContainer,
        fetchingController: PhotosListFetchingControllerProtocol,
        selectionController: PhotosSelectionController,
        rootFolderRepository: PhotosRootFolderRepository,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        featureFlagsController: FeatureFlagsControllerProtocol,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>,
        metadataController: MetadataControllerProtocol,
        configuration: PhotosRootConfiguration,
        offlineAvailableResource: OfflineAvailableResource,
        infosController: PhotoAdditionalInfosController,
        remoteAlbumFetchController: RemoteAlbumFetchControllerProtocol,
        streamConfiguration: PhotoStreamConfiguration,
        scrollerController: GridScrollerControllerProtocol,
        bannersView: some View,
        scrollerView: some View,
        itemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol
    ) -> some View {
        let offlineAvailableController = UpdatingOfflineAvailableController(resource: offlineAvailableResource)
        let monthFormatter = LocalizedMonthFormatter(dateResource: PlatformCurrentDateResource(), dateFormatter: PlatformMonthAndYearFormatter(), monthResource: PlatformMonthResource())
        let viewModel = PhotosGridViewModel(
            controller: listController,
            fetchingController: fetchingController,
            monthFormatter: monthFormatter,
            configuration: configuration,
            selectionController: selectionController,
            remoteAlbumFetchController: remoteAlbumFetchController,
            scrollToTopPublisher: scrollToTopPublisher,
            streamConfiguration: streamConfiguration,
            scrollerController: scrollerController,
            performanceMetricsController: tower.performanceMetricsController
        )
        
        let localSelection: PhotosSelectionController
        if configuration.isPickingPhotos {
            // To prevent tabbar hidden status is changed unexpected
            localSelection = LocalPhotosSelectionController()
            localSelection.start(selectedID: [])
        } else {
            localSelection = selectionController
        }
        let actionView = makeActionView(
            tower: tower,
            selectionController: localSelection,
            coordinator: coordinator,
            offlineAvailableController: offlineAvailableController,
            rootFolderRepository: rootFolderRepository,
            photosManagedObjectContext: photosManagedObjectContext,
            photoUploadedNotifier: photoUploadedNotifier,
            featureFlagsController: featureFlagsController,
            metadataController: metadataController,
            streamConfiguration: streamConfiguration,
            configuration: configuration
        )
        return PhotosGridView(
            viewModel: viewModel,
            navigationFactory: PhotosRootNavigationButtonFactory(),
            actionView: actionView,
            bannersView: bannersView,
            scrollerView: scrollerView
        ) { item, accessibilityIndex in
            return PhotoItemWrapperView {
                let viewModel = itemViewModelFactory.makeViewModel(for: item)
                return PhotoItemView(
                    viewModel: viewModel,
                    accessibilityIndex: accessibilityIndex,
                    isPickingPhotos: configuration.isPickingPhotos
                )
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func makeActionView(
        tower: Tower,
        selectionController: PhotosSelectionController,
        coordinator: GalleryCoordinator,
        offlineAvailableController: OfflineAvailableController,
        rootFolderRepository: PhotosRootFolderRepository,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        featureFlagsController: FeatureFlagsControllerProtocol,
        metadataController: MetadataControllerProtocol,
        streamConfiguration: PhotoStreamConfiguration,
        configuration: PhotosRootConfiguration
    ) -> some View {
        let trashController = makeTrashController(tower: tower)
        let fileContentController = makeFileContentController(
            tower: tower,
            featureFlagsController: featureFlagsController,
            moc: photosManagedObjectContext,
            photoUploadedNotifier: photoUploadedNotifier
        )
        let favoritingController = makeFavoritingController(
            tower: tower,
            managedObjectContext: photosManagedObjectContext
        )
        let trashDialogFactory = TrashDialogFactory(
            dependencies: .init(
                context: photosManagedObjectContext,
                trashController: trashController,
                selectionController: selectionController,
                removePhotosController: nil,
                eventsSystemManager: tower,
                userMessageHandler: UserMessageHandler()
            )
        )
        let viewModel = PhotoGalleryActionViewModel(
            coordinator: coordinator,
            selectionController: selectionController,
            fileContentController: fileContentController,
            offlineAvailableController: offlineAvailableController,
            featureFlagsController: featureFlagsController,
            metadataController: metadataController,
            favoritingController: favoritingController,
            trashDialogFactory: trashDialogFactory,
            userMessageHandler: UserMessageHandler(),
            streamConfiguration: streamConfiguration,
            configuration: configuration
        )
        return PhotosActionView(viewModel: viewModel)
    }

    func makeFavoritingController(tower: Tower, managedObjectContext: NSManagedObjectContext) -> FavoritingControllerProtocol {
        let tagRepository = PhotoTagUpdateRepository()
        let localRepository = LocalFavoritingRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage, tagRepository: tagRepository)
        let remoteRepository = RemoteFavoritingRepository(tagClient: tower.client)
        let parametersFactory = FavoritingAlbumPhotoParametersFactory(
            managedObjectContext: managedObjectContext,
            storageManager: tower.storage,
            cryptoMaterialReader: NodeCryptoMaterialReader(moc: managedObjectContext, signersKitFactory: tower.sessionVault),
            encryptionResource: Encryptor()
        )
        let duplicateCheckRepository = PhotosDuplicateCheckRepositoryFactory().makeRepository(
            tower: tower,
            managedObjectContext: managedObjectContext
        )
        let addFavoriteTagInteractor = AddFavoriteTagInteractor(
            localRepository: localRepository,
            remoteRepository: remoteRepository,
            parametersFactory: parametersFactory,
            duplicateCheckRepository: duplicateCheckRepository
        )
        let removeFavoriteTagInteractor = RemoveFavoriteTagInteractor(
            localRepository: localRepository,
            remoteRepository: remoteRepository
        )
        let interactor = FavoritingInteractor(
            localRepository: localRepository,
            addFavoriteTagInteractor: addFavoriteTagInteractor,
            removeFavoriteTagInteractor: removeFavoriteTagInteractor
        )
        let facade = FavoritingFacade(interactor: interactor)
        return FavoritingController(facade: facade)
    }

    func makeTrashController(tower: Tower) -> PhotosTrashController {
        if let performer = tower.sdkObjects.nodeOperationPerformer {
            let interactor = SDKPhotosTrashInteractor(
                downloader: tower.sdkObjects.photoDownloader,
                performer: performer
            )
            let facade = AsyncSDKPhotosTrashFacade(interactor: interactor)
            return LocalPhotosTrashController(facade: facade)
        } else {
            let remoteRepository = BackendRemotePhotosTrashRepository(trasher: tower.cloudSlot)
            let localRepository = DatabasePhotosTrashRepository(storageManager: tower.storage)
            let trashInteractor = PhotosTrashInteractor(remoteRepository: remoteRepository, localRepository: localRepository)
            let trashFacade = AsyncPhotosTrashFacade(interactor: trashInteractor)
            return LocalPhotosTrashController(facade: trashFacade)
        }
    }

    // swiftlint:disable:next function_parameter_count
    func makeItemViewModel(item: PhotoGridViewItem, thumbnailsContainer: ThumbnailsControllersContainer, coordinator: PhotoItemCoordinator, selectionController: PhotosSelectionController, infosController: PhotoAdditionalInfosController, featureFlagsController: FeatureFlagsControllerProtocol, fetchingController: PhotosListFetchingControllerProtocol, metadataController: MetadataControllerProtocol) -> PhotoItemViewModel {
        let id = PhotoId(id: item.photoId, volumeID: item.volumeId)
        let infoController = ConcretePhotoAdditionalInfoController(id: id, controller: infosController)
        let thumbnailController = thumbnailsContainer.makeSmallThumbnailController(id: id)
        let viewModel = PhotoItemViewModel(item: item, thumbnailController: thumbnailController, coordinator: coordinator, selectionController: selectionController, infoController: infoController, durationFormatter: LocalizedDurationFormatter(), debounceResource: CommonLoopDebounceResource(), fetchingController: fetchingController, featureFlagsController: featureFlagsController, metadataController: metadataController)
        return viewModel
    }

    // swiftlint:disable:next function_parameter_count
    func makeNewShareViewController(
        identifier: PhotoId,
        tower: Tower,
        storage: StorageManager,
        contactsManager: ContactsManagerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol,
        rootViewController: UIViewController,
        sharingMemberFactory: SharingMemberStartFactoryProtocol
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

    func makeTagsView(
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        tagsController: GalleryTagsControllerProtocol
    ) -> some View {
        let viewModel = GalleryTagsViewModel(
            tagsController: tagsController,
            listController: listController,
            fetchingController: fetchingController
        )
        return GalleryTagsView(viewModel: viewModel)
    }

    // MARK: - Controllers

    func makePreviewController(controller: PhotosListControllerProtocol, currentId: PhotoId) -> PhotosPreviewController {
        ListingPhotosPreviewController(controller: controller, currentId: currentId)
    }

    func makeFileContentController(
        tower: Tower,
        featureFlagsController: FeatureFlagsControllerProtocol,
        moc: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier
    ) -> FileContentController {
        let contentResource = DecryptedPhotoContentResource(
            managedObjectContext: moc,
            sdkDownloader: tower.sdkObjects.photoDownloader,
            fetchResource: PhotoFetchResource(storage: tower.storage),
            photoUploadedNotifier: photoUploadedNotifier,
            performanceMetricsController: tower.performanceMetricsController,
            photoDecryptor: RemoteFileContentDecryptor(validator: PhotoURLValidationResource())
        )
        return LocalFileContentController(resource: contentResource, storageResource: LocalFileStorageResource())
    }

    func makeInfosController(managedObjectContext: NSManagedObjectContext) -> PhotoAdditionalInfosController {
        let repository = CoreDataPhotoAdditionalInfoRepository(managedObjectContext: managedObjectContext)
        return ConcretePhotoAdditionalInfosController(repository: repository)
    }

    func makeOfflineAvailableResource(tower: Tower, managedObjectContext: NSManagedObjectContext) -> OfflineAvailableResource {
        LocalOfflineAvailableResource(
            tower: tower,
            downloader: tower.downloader,
            sdkDownloader: tower.sdkObjects.photoDownloader,
            storage: tower.storage,
            managedObjectContext: managedObjectContext
        )
    }

    func makeTrashDialogFactory(
        albumID: AlbumIdentifier?,
        context: NSManagedObjectContext,
        selectionController: PhotosSelectionController?,
        tower: Tower
    ) -> TrashDialogFactory {
        var removePhotosController: RemovePhotosControllerProtocol?
        if let albumID {
            removePhotosController = AlbumDetailFactory().makeRemovePhotosController(
                albumID: albumID,
                managedObjectContext: context,
                tower: tower
            )
        }
        return .init(
            dependencies: .init(
                context: context,
                trashController: makeTrashController(tower: tower),
                selectionController: selectionController ?? LocalPhotosSelectionController(),
                removePhotosController: removePhotosController,
                eventsSystemManager: tower,
                userMessageHandler: UserMessageHandler()
            )
        )
    }
}
