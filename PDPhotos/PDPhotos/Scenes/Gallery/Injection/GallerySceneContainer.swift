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

import Combine
import CoreData
import PDCore
import PDCoreIOS
import PDContacts
import PDUIComponents
import ProtonCoreKeymaker
import ProtonCoreServices
import SwiftUI
import UIKit

final class GallerySceneContainer {
    struct Dependencies {  // TODO: `Albums` related: refactor if possible into standalone struct without coupling with parent
        let parentDependencies: PDPhotosContainer.Dependencies
        let managedObjectContext: NSManagedObjectContext
        var tower: Tower { parentDependencies.tower }
        let metadataController: MetadataControllerProtocol
        let streamThumbnailsContainer: ThumbnailsControllersContainer
        let albumsThumbnailsContainer: ThumbnailsControllersContainer // Once thumbnails are supported by SDK get back to a single thumbnailsContainer
        let tagsController: GalleryTagsControllerProtocol
    }
    let streamConfiguration: PhotoStreamConfiguration
    let dependencies: Dependencies
    let streamListController: PhotosListControllerProtocol
    let offlineAvailableResource: OfflineAvailableResource
    let fetchingController: PhotosListFetchingControllerProtocol
    let initialLoadController: PhotosListFetchingStatusControllerProtocol
    let anchorController: PhotosListAnchorControllerProtocol
    let scrollerController: GridScrollerControllerProtocol
    private let itemsViewModelsCache: PhotoItemViewModelsCache

    var volumeId: VolumeID {
        streamConfiguration.volumeId
    }

    // We need to share same reference for multiple constructed scenes, but want them released when all screens are dismissed.
    private(set) weak var parent: PhotosScenesContainer?
    private weak var previewController: PhotosPreviewController?
    private weak var infosController: PhotoAdditionalInfosController?

    init(dependencies: Dependencies, streamConfiguration: PhotoStreamConfiguration, parent: PhotosScenesContainer) {
        self.dependencies = dependencies
        self.streamConfiguration = streamConfiguration
        self.parent = parent
        let factory = GalleryScenesFactory()
        offlineAvailableResource = factory.makeOfflineAvailableResource(
            tower: dependencies.tower,
            managedObjectContext: dependencies.managedObjectContext
        )
        let configuration = PhotosListConfiguration(volumeId: streamConfiguration.volumeId, albumId: nil, shouldLoadAllAtOnce: true)
        streamListController = PhotosListControllerFactory().makeListController(
            tower: dependencies.tower,
            configuration: configuration,
            managedObjectContext: dependencies.managedObjectContext,
            offlineAvailableResource: offlineAvailableResource
        )
        let listFetchingFactory = PhotosListFetchingControllerFactory()
        anchorController = listFetchingFactory.makeAnchorController()
        fetchingController = listFetchingFactory.makeController(
            tower: dependencies.tower,
            configuration: configuration,
            managedObjectContext: dependencies.managedObjectContext,
            anchorController: anchorController,
            errorController: dependencies.parentDependencies.legacyShareErrorController
        )
        initialLoadController = PhotosListFetchingControllerFactory().makeInitialStatusController(fetchingController: fetchingController)
        scrollerController = GridScrollerControllerFactory().makeController(listController: streamListController, fetchingController: fetchingController)
        itemsViewModelsCache = PhotoItemViewModelsCache()
    }

    func makeMainView(
        rootViewController: UIViewController?,
        configuration: PhotosRootConfiguration,
        selectionController: PhotosSelectionController,
        screenLockController: ScreenLockController
    ) -> some View {
        let factory = GalleryScenesFactory()
        let coordinator = factory.makeCoordinator(container: self)
        coordinator.rootViewController = rootViewController

        return factory.makeRootView(
            configuration: configuration,
            settingsController: dependencies.parentDependencies.settingsController,
            authorizationController: dependencies.parentDependencies.authorizationController,
            listController: streamListController,
            fetchingController: fetchingController,
            initialLoadController: initialLoadController,
            photoUpsellFlowController: makePhotoUpsellController(
                coordinator: coordinator,
                notificationsPermissionsFlowController: dependencies.parentDependencies.notificationsPermissionsFlowController
            ),
            managedObjectContext: dependencies.managedObjectContext,
            volumeId: volumeId,
            screenLockController: screenLockController,
            onboardingView: { [unowned self] in
                makeOnboardingView()
            },
            permissionsView: {
                factory.makePermissionsView(coordinator: coordinator)
            },
            galleryView: makeGalleryView(
                coordinator: coordinator,
                selectionController: configuration.selectionController ?? selectionController,
                listController: streamListController,
                fetchingController: fetchingController,
                configuration: configuration,
                screenLockController: screenLockController,
                streamConfiguration: streamConfiguration,
                scrollerController: scrollerController
            )
        )
    }

    func makeAlbumGallery(
        rootViewController: UIViewController?,
        configuration: PhotosRootConfiguration,
        streamConfiguration: PhotoStreamConfiguration
    ) -> some View {
        let pendingInvitationsContainer = makePendingInvitationsContainer()
        let coordinator = AlbumGalleryCoordinator(
            container: self,
            pendingInvitationsContainer: pendingInvitationsContainer,
            rootViewController: rootViewController
        )
        let context = dependencies.managedObjectContext
        let factory = PDPhotosFactory()
        let localAlbumListController = factory.makeLocalAlbumListController(
            context: context,
            storageManger: dependencies.tower.storage,
            streamConfiguration: streamConfiguration
        )
        let remoteAlbumFetchController = factory.makeRemoteAlbumFetchController(
            context: context,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController,
            tower: dependencies.tower,
            streamConfiguration: streamConfiguration,
            contactsManager: dependencies.parentDependencies.contactsManager
        )
        let galleryFactory = AlbumGalleryFactory()
        let invitationsController = galleryFactory.makeInvitationsController(container: pendingInvitationsContainer)
        let viewModel = AlbumGalleryViewModel(
            dependencies: .init(
                coordinator: coordinator,
                context: context,
                localAlbumListController: localAlbumListController,
                selectionController: configuration.selectionController ?? LocalPhotosSelectionController(),
                metadataController: dependencies.metadataController,
                remoteAlbumFetchController: remoteAlbumFetchController,
                thumbnailContainer: dependencies.albumsThumbnailsContainer,
                invitationsController: invitationsController,
                invitationsChangeController: pendingInvitationsContainer.changeController
            ),
            configuration: configuration
        )
        let invitationsView = galleryFactory.makeInvitationsView(
            controller: invitationsController,
            coordinator: coordinator
        )
        return AlbumGalleryView(viewModel: viewModel, invitationsView: invitationsView)
    }

    private func makePendingInvitationsContainer() -> PendingInvitationsContainer {
        PendingInvitationsContainer(
            tower: dependencies.tower,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController,
            configuration: .albums
        )
    }

    private func makeOnboardingView() -> some View {
        let factory = GalleryScenesFactory()
        return factory.makeOnboardingView(
            settingsController: dependencies.parentDependencies.settingsController,
            authorizationController: dependencies.parentDependencies.authorizationController
        )
    }

    private func makeGalleryView(
        coordinator: GalleryCoordinator,
        selectionController: PhotosSelectionController,
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        configuration: PhotosRootConfiguration,
        screenLockController: ScreenLockController,
        streamConfiguration: PhotoStreamConfiguration,
        scrollerController: GridScrollerControllerProtocol
    ) -> some View {
        let factory = GalleryScenesFactory()
        let backupStartController = SimplePhotosBackupStartController(
            settingsController: dependencies.parentDependencies.settingsController,
            authorizationController: dependencies.parentDependencies.authorizationController
        )
        let stateView = factory.makeStateView(
            controller: dependencies.parentDependencies.backupStateController,
            coordinator: coordinator,
            constraintsController: dependencies.parentDependencies.constraintsController,
            backupStartController: backupStartController,
            settingsController: dependencies.parentDependencies.settingsController,
            userMessageHandler: dependencies.parentDependencies.userMessageHandler
        )
        let lockingBannerView = LockingBannerFactory().makeBanner(controller: screenLockController)
        let tagsView = factory.makeTagsView(
            listController: listController,
            fetchingController: fetchingController,
            tagsController: dependencies.tagsController
        )
        let storageView = factory.makeStorageView(
            quotaStateController: dependencies.parentDependencies.quotaStateController,
            progressController: dependencies.parentDependencies.backupProgressController,
            coordinator: coordinator
        )
        let bannersView = factory.makeBannersView(
            stateView: stateView,
            lockingBannerView: lockingBannerView,
            storageView: storageView
        )
        let remoteAlbumFetchController = PDPhotosFactory().makeRemoteAlbumFetchController(
            context: dependencies.managedObjectContext,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController,
            tower: dependencies.tower,
            streamConfiguration: streamConfiguration,
            contactsManager: dependencies.parentDependencies.contactsManager
        )
        let scrollerView = factory.makeScrollerView(scrollerController: scrollerController)
        return factory.makeGalleryView(
            tower: dependencies.tower,
            coordinator: coordinator,
            listController: listController,
            fetchingController: fetchingController,
            thumbnailsContainer: dependencies.streamThumbnailsContainer,
            settingsController: dependencies.parentDependencies.settingsController,
            errorControllers: [dependencies.parentDependencies.processingController],
            selectionController: selectionController,
            rootFolderRepository: dependencies.parentDependencies.rootFolderRepository,
            photosManagedObjectContext: dependencies.parentDependencies.photosManagedObjectContext,
            photoUploadedNotifier: dependencies.parentDependencies.photoUploadedNotifier,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController,
            scrollToTopPublisher: dependencies.parentDependencies.scrollToTopPublisher,
            metadataController: dependencies.metadataController,
            configuration: configuration,
            offlineAvailableResource: offlineAvailableResource,
            tagsController: dependencies.tagsController,
            infosController: getInfosController(),
            remoteAlbumFetchController: remoteAlbumFetchController,
            streamConfiguration: streamConfiguration,
            scrollerController: scrollerController,
            // So we won’t reuse the same PhotoItemViewModel for both the gallery and the photo picker
            itemsViewModelsCache: configuration.isPickingPhotos ? PhotoItemViewModelsCache() : itemsViewModelsCache,
            bannersView: bannersView,
            tagsView: tagsView,
            scrollerView: scrollerView
        )
    }

    func makePreviewController(id: PhotoId, albumId: AlbumIdentifier?) -> UIViewController {
        let dependencies = PhotosPreviewContainer.Dependencies(
            id: id,
            albumId: albumId,
            tower: dependencies.parentDependencies.tower,
            listController: makeListController(albumId: albumId),
            thumbnailsContainer: albumId == nil ? dependencies.streamThumbnailsContainer : dependencies.albumsThumbnailsContainer,
            photosManagedObjectContext: dependencies.parentDependencies.photosManagedObjectContext,
            photoUploadedNotifier: dependencies.parentDependencies.photoUploadedNotifier,
            metadataController: dependencies.metadataController,
            offlineAvailableResource: offlineAvailableResource,
            parentDependencies: dependencies
        )
        let container = PhotosPreviewContainer(dependencies: dependencies, gallerySceneContainer: self)
        return container.makeRootViewController(with: id, albumID: albumId)
    }

    func makeShareViewController(id: PhotoId, rootVC: UIViewController) -> SharingStartCoordinator? {
        let factory = GalleryScenesFactory()
        return factory.makeNewShareViewController(
            identifier: id,
            tower: dependencies.tower,
            storage: dependencies.tower.storage,
            contactsManager: dependencies.parentDependencies.contactsManager,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController,
            rootViewController: rootVC,
            sharingMemberFactory: dependencies.parentDependencies.sharingMemberFactory
        )
    }

    func makeSubscriptionsViewController() -> UIViewController {
        let dependencies = SubscriptionsContainer.Dependencies(
            tower: dependencies.parentDependencies.tower,
            keymaker: dependencies.parentDependencies.keymaker,
            networkService: dependencies.parentDependencies.networkService,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController
        )
        let container = SubscriptionsContainer(dependencies: dependencies)
        return container.makeRootViewController()
    }

    func makeRetryViewController() -> UIViewController {
        GalleryScenesFactory().makeRetryViewController(
            deletedStoreResource: dependencies.parentDependencies.failedPhotosResource,
            retryTriggerController: dependencies.parentDependencies.retryTriggerController
        )
    }

    func makePhotoUpsellController(
        coordinator: GalleryCoordinator,
        notificationsPermissionsFlowController: NotificationsPermissionsFlowController
    ) -> PhotoUpsellFlowController? {
        return PhotoUpsellFactory().makeController(
            tower: dependencies.tower,
            coordinator: coordinator,
            notificationsPermissionsFlowController: notificationsPermissionsFlowController,
            photoUploadedNotifier: dependencies.parentDependencies.photoUploadedNotifier,
            photoUpsellResultNotifier: dependencies.parentDependencies.photoUpsellResultNotifier
        )
    }

    func makeInvitationsListViewController() -> UIViewController {
        let container = PendingInvitationsContainer(tower: dependencies.tower, featureFlagsController: dependencies.parentDependencies.featureFlagsController, configuration: .albums)
        return container.makePendingInvitationsListView().embeddedInHostingController()
    }

    private func makeListController(albumId: AlbumIdentifier?) -> PhotosListControllerProtocol {
        guard let albumId else {
            return streamListController
        }
        return PhotosListControllerFactory().makeListController(
            tower: dependencies.tower,
            configuration: PhotosListConfiguration(volumeId: albumId.volumeID, albumId: albumId.id),
            managedObjectContext: dependencies.managedObjectContext,
            offlineAvailableResource: offlineAvailableResource
        )
    }

    // MARK: - Cached controllers

    private func getInfosController() -> PhotoAdditionalInfosController {
        let infosController = infosController ?? GalleryScenesFactory().makeInfosController(managedObjectContext: dependencies.managedObjectContext)
        self.infosController = infosController
        return infosController
    }
}
