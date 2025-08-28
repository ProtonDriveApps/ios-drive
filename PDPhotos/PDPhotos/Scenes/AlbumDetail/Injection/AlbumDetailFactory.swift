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
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

struct AlbumDetailFactory {
    struct Parameters {
        let albumID: AlbumIdentifier
        let configuration: PhotosRootConfiguration
        let contactsController: ContactsControllerProtocol
        let container: GallerySceneContainer
        let defaultAppearance: NavigationBarAppearance?
        let rootViewController: UIViewController?
        let shouldOpenInvitation: Bool

        init(
            albumID: AlbumIdentifier,
            configuration: PhotosRootConfiguration,
            contactsController: ContactsControllerProtocol,
            container: GallerySceneContainer,
            defaultAppearance: NavigationBarAppearance?,
            rootViewController: UIViewController?,
            shouldOpenInvitation: Bool = false
        ) {
            self.albumID = albumID
            self.configuration = configuration
            self.contactsController = contactsController
            self.container = container
            self.defaultAppearance = defaultAppearance
            self.rootViewController = rootViewController
            self.shouldOpenInvitation = shouldOpenInvitation
        }
    }

    func makeAlbumDetail(parameters: Parameters) -> UIViewController {
        guard
            let mainContainer = parameters.container.parent?.parent
        else { return UIViewController() }
        let context = parameters.container.dependencies.managedObjectContext
        let tower = parameters.container.dependencies.tower
        let repository = AlbumRepository(albumID: parameters.albumID, managedObjectContext: context)
        let coordinator = AlbumDetailCoordinator(
            container: parameters.container,
            defaultBarAppearance: parameters.defaultAppearance,
            rootViewController: parameters.rootViewController
        )
        let selectionController = parameters.configuration.selectionController ?? LocalPhotosSelectionController()

        let factory = AlbumGalleryFactory()
        let listController = factory.makeListController(
            id: parameters.albumID,
            managedObjectContext: context,
            tower: tower,
            offlineAvailableResource: parameters.container.offlineAvailableResource
        )
        let fetchingController = factory.makeFetchingController(
            id: parameters.albumID,
            managedObjectContext: context,
            tower: tower,
            anchorController: parameters.container.anchorController,
            errorController: mainContainer.dependencies.legacyShareErrorController
        )
        let photoGridViewModel = factory.makeGridViewModel(
            listController: listController,
            fetchingController: fetchingController,
            selectionController: selectionController,
            streamConfiguration: parameters.container.streamConfiguration
        )
        let itemViewModelFactory = factory.makeItemViewModelFactory(
            fetchingController: fetchingController,
            container: parameters.container,
            selectionController: selectionController,
            rootViewController: parameters.rootViewController
        )
        let deletionFlowController = makeDeletionFlowController(
            context: context,
            coordinator: coordinator,
            tower: tower
        )
        let inviteeInteractor = RemoteInviteeListLoadInteractor(client: parameters.container.dependencies.tower.client)
        let inviteeListLoadController = InviteeListLoadController(
            dependencies: .init(
                contactsController: parameters.contactsController,
                inviteeListLoadInteractor: AsyncRemoteInviteeListLoadInteractor(interactor: inviteeInteractor)
            )
        )
        let leaveFlowController = makeLeaveFlowController(tower: tower, context: context, coordinator: coordinator, albumId: parameters.albumID)
        let contentController = GalleryScenesFactory().makeFileContentController(
            tower: parameters.container.dependencies.tower,
            moc: parameters.container.dependencies.managedObjectContext,
            photoUploadedNotifier: parameters.container.dependencies.parentDependencies.photoUploadedNotifier
        )
        let copyToStreamController = CopyPhotosControllerFactory().makeCopyPhotosController(
            tower: tower,
            context: context,
            albumId: parameters.albumID
        )
        let viewModel = AlbumDetailViewModel(
            dependencies: .init(
                addPhotoSelectionController: LocalPhotosSelectionController(),
                addToAlbumController: AddPhotosToAlbumControllerFactory().makeController(
                    tower: tower,
                    managedObjectContext: context
                ),
                albumLeaveFlowController: leaveFlowController,
                albumRepository: repository,
                coordinator: coordinator,
                contentController: contentController,
                deletionFlowController: deletionFlowController,
                featureFlagsController: mainContainer.dependencies.featureFlagsController,
                inviteeListLoadController: inviteeListLoadController,
                itemViewModelFactory: itemViewModelFactory,
                photosGridViewModel: photoGridViewModel,
                selectionController: selectionController,
                thumbnailControllerContainer: parameters.container.dependencies.thumbnailsContainer,
                copyToStreamController: copyToStreamController
            ),
            configuration: parameters.configuration,
            shouldOpenInvitation: parameters.shouldOpenInvitation
        )
        let actionView = makeActionView(
            albumRepository: repository,
            container: parameters.container,
            rootViewController: parameters.rootViewController,
            selectionController: selectionController
        )
        let view = AlbumDetailView(viewModel: viewModel, actionView: actionView)
        let vc = UIHostingController(rootView: view)
        vc.view.backgroundColor = ColorProvider.BackgroundNorm
        return vc
    }

    private func makeLeaveFlowController(
        tower: Tower,
        context: NSManagedObjectContext,
        coordinator: AlbumDetailCoordinatorProtocol,
        albumId: AnyVolumeIdentifier
    ) -> AlbumLeaveFlowController {
        let interactor = makeAlbumCopyAllInteractor(tower: tower, managedObjectContext: context, albumId: albumId)
        let messageHandler = UserMessageHandler()
        return AlbumLeaveFlowController(
            dependencies: .init(
                context: context,
                coordinator: coordinator,
                client: tower.client,
                eventsSystemManager: tower,
                userMessageHandler: messageHandler,
                copyAllInteractor: interactor,
                copyMessageHandler: CopyPhotosMessageHandler(
                    messageHandler: PhotoStreamMoveOperationMessageHandler(userMessageHandler: messageHandler)
                )
            )
        )
    }

    private func makeAlbumCopyAllInteractor(
        tower: Tower,
        managedObjectContext: NSManagedObjectContext,
        albumId: AnyVolumeIdentifier
    ) -> AlbumCopyAllPhotosInteractorProtocol {
        let listConfiguration = PhotosListConfiguration(volumeId: albumId.volumeID, albumId: albumId.id)
        let listingFetchInteractor = PhotosListFetchingControllerFactory().makeInteractor(
            tower: tower,
            configuration: listConfiguration,
            managedObjectContext: managedObjectContext
        )
        let metadataRepository = PDPhotosFactory().makeRemoteMetadataFetchRepository(tower: tower, managedObjectContext: managedObjectContext)
        let copyInteractor = CopyPhotosControllerFactory().makeCopyPhotosInteractor(tower: tower, context: managedObjectContext)
        let rootRepository = PhotoVolumeRootFolderIdRepository(storageManager: tower.storage, managedObjectContext: managedObjectContext)
        let fetchInteractor = AlbumAllChildrenInteractor(
            fetchInteractor: listingFetchInteractor,
            metadataRepository: metadataRepository
        )
        return AlbumCopyAllPhotosInteractor(
            fetchInteractor: fetchInteractor,
            copyInteractor: copyInteractor,
            rootRepository: rootRepository
        )
    }

    private func makeActionView(
        albumRepository: AlbumRepositoryProtocol,
        container: GallerySceneContainer,
        rootViewController: UIViewController?,
        selectionController: PhotosSelectionController
    ) -> some View {
        let tower = container.dependencies.tower
        let context = container.dependencies.managedObjectContext
        let factory = GalleryScenesFactory()
        let fileContentController = factory.makeFileContentController(
            tower: tower,
            moc: context,
            photoUploadedNotifier: container.dependencies.parentDependencies.photoUploadedNotifier
        )
        let removePhotosController = makeRemovePhotosController(
            albumID: albumRepository.albumID,
            managedObjectContext: context,
            tower: tower
        )
        let offlineAvailableController = UpdatingOfflineAvailableController(resource: container.offlineAvailableResource)
        let coordinator = GalleryCoordinator(container: container)
        coordinator.rootViewController = rootViewController
        let updateInteractor = makeUpdateAlbumInteractor(context: context, tower: tower)
        let trashController = factory.makeTrashController(tower: tower)
        let trashDialogFactory = TrashDialogFactory(
            dependencies: .init(
                context: context,
                trashController: trashController,
                selectionController: selectionController,
                removePhotosController: removePhotosController,
                eventsSystemManager: tower,
                userMessageHandler: UserMessageHandler()
            )
        )
        let copyToStreamController = CopyPhotosControllerFactory().makeCopyPhotosController(
            tower: tower,
            context: context,
            albumId: albumRepository.albumID
        )
        let viewModel = AlbumActionViewModel(
            coordinator: coordinator,
            selectionController: selectionController,
            fileContentController: fileContentController,
            offlineAvailableController: offlineAvailableController,
            featureFlagsController: container.dependencies.parentDependencies.featureFlagsController,
            metadataController: container.dependencies.metadataController,
            favoritingController: factory.makeFavoritingController(tower: tower, managedObjectContext: context),
            trashDialogFactory: trashDialogFactory,
            userMessageHandler: UserMessageHandler(),
             updateAlbumInteractor: updateInteractor,
            albumRepository: albumRepository,
            copyToStreamController: copyToStreamController
        )
        return PhotosActionView(viewModel: viewModel)
    }

    private func makeUpdateAlbumInteractor(
        context: NSManagedObjectContext,
        tower: Tower
    ) -> UpdateAlbumInteractor {
        let provider = PhotoRootInfoProvider(
            dependencies: .init(
                managedObjectContext: context,
                storageManager: tower.storage
            )
        )
        return UpdateAlbumInteractor(
            dependencies: .init(
                client: tower.client,
                managedObjectContext: context,
                photoRootInfoProvider: provider,
                signersKitFactory: tower.sessionVault,
                requestFactory: UpdateAlbumRequestFactory(
                    managedObjectContext: context,
                    encryptionResource: Encryptor(),
                    signersKitFactory: tower.sessionVault
                )
            )
        )
    }

    func makeRemovePhotosController(
        albumID: AnyVolumeIdentifier,
        managedObjectContext: NSManagedObjectContext,
        tower: Tower
    ) -> RemovePhotosController {
        let repository = CoreDataDeletePhotoListingsRepository(managedObjectContext: managedObjectContext)
        return .init(
            albumID: albumID,
            dependencies: .init(
                client: tower.client,
                repository: repository,
                albumContentOperationMessenger: AlbumContentOperationMessenger(userMessageHandler: UserMessageHandler())
            )
        )
    }

    private func makeDeletionFlowController(
        context: NSManagedObjectContext,
        coordinator: AlbumDetailCoordinatorProtocol,
        tower: Tower
    ) -> AlbumDeletionFlowController {
        let deleteAlbumController = AlbumGalleryFactory().makeDeleteAlbumController(
            managedObjectContext: context,
            tower: tower
        )
        let storeRepository = PhotosListFetchingControllerFactory()
            .makeStoreListingRepository(managedObjectContext: context)
        let metadataFetchRepository = PDPhotosFactory().makeRemoteMetadataFetchRepository(tower: tower, managedObjectContext: context)
        let fetchInteractor = DirectChildrenInAlbumFetchInteractor(
            dependencies: .init(
                listRepository: tower.client,
                metadataRepository: metadataFetchRepository,
                storeListingRepository: storeRepository
            )
        )
        let filterPolicy = AlbumDirectChildrenFilterPolicy(context: context)
        return .init(
            dependencies: .init(
                coordinator: coordinator,
                deleteAlbumController: deleteAlbumController,
                eventsSystemManager: tower,
                fetchInteractor: fetchInteractor,
                filterPolicy: filterPolicy
            )
        )
    }
}
