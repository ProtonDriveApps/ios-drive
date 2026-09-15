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

import PDCore
import CoreData
import Combine
import UIKit
import PDCoreIOS
import SwiftUI

struct AlbumGalleryFactory {
    func makeGridViewModel(
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        selectionController: PhotosSelectionController,
        streamConfiguration: PhotoStreamConfiguration,
        performanceMetricsController: PerformanceMetricsControllerProtocol?
    ) -> PhotosGridViewModel {
        let monthFormatter = LocalizedMonthFormatter(dateResource: PlatformCurrentDateResource(), dateFormatter: PlatformMonthAndYearFormatter(), monthResource: PlatformMonthResource())
        return PhotosGridViewModel(
            controller: listController,
            fetchingController: fetchingController,
            monthFormatter: monthFormatter,
            configuration: .init(), // TODO:album inject correct configuration
            selectionController: selectionController,
            remoteAlbumFetchController: nil,
            scrollToTopPublisher: PassthroughSubject().eraseToAnyPublisher(),
            streamConfiguration: streamConfiguration,
            scrollerController: nil,
            performanceMetricsController: performanceMetricsController
        )
    }

    func makeListController(
        id: AnyVolumeIdentifier,
        managedObjectContext: NSManagedObjectContext,
        tower: Tower,
        offlineAvailableResource: OfflineAvailableResource
    ) -> PhotosListControllerProtocol {
        let configuration = PhotosListConfiguration(volumeId: id.volumeID, albumId: id.id)
        return PhotosListControllerFactory().makeListController(
            tower: tower,
            configuration: configuration,
            managedObjectContext: managedObjectContext,
            offlineAvailableResource: offlineAvailableResource
        )
    }

    func makeFetchingController(
        id: AnyVolumeIdentifier,
        managedObjectContext: NSManagedObjectContext,
        tower: Tower,
        anchorController: PhotosListAnchorControllerProtocol,
        errorController: ErrorSetControllerProtocol
    ) -> PhotosListFetchingControllerProtocol {
        let configuration = PhotosListConfiguration(volumeId: id.volumeID, albumId: id.id)
        return PhotosListFetchingControllerFactory().makeController(
            tower: tower,
            configuration: configuration,
            managedObjectContext: managedObjectContext,
            anchorController: anchorController,
            errorController: errorController
        )
    }

    func makeItemViewModelFactory(
        fetchingController: PhotosListFetchingControllerProtocol,
        container: GallerySceneContainer,
        selectionController: PhotosSelectionController,
        rootViewController: UIViewController?
    ) -> CachingPhotoItemViewModelFactory {
        let galleryFactory = GalleryScenesFactory()
        let infosController = ConcretePhotoAdditionalInfosController(
            repository: CoreDataPhotoAdditionalInfoRepository(managedObjectContext: container.dependencies.managedObjectContext)
        )
        let galleryCoordinator = GalleryCoordinator(container: container)
        galleryCoordinator.rootViewController = rootViewController
        let thumbnailCache = SmallThumbnailURLCache()
        let itemViewModelFactory = CachingPhotoItemViewModelFactory(cache: PhotoItemViewModelsCache()) { item in
            galleryFactory.makeItemViewModel(
                item: item,
                coordinator: galleryCoordinator,
                selectionController: selectionController,
                infosController: infosController,
                featureFlagsController: container.dependencies.parentDependencies.featureFlagsController,
                fetchingController: fetchingController,
                metadataController: container.dependencies.metadataController,
                thumbnailDownloader: container.dependencies.tower.sdkObjects.thumbnailDownloader,
                thumbnailCache: thumbnailCache
            )
        }
        return itemViewModelFactory
    }

    func makeCreateAlbumController(
        managedObjectContext: NSManagedObjectContext,
        tower: Tower,
        volumeID: VolumeID
    ) -> CreateAlbumController {
        let createAlbumInteractor = makeCreateAlbumInteractor(
            managedObjectContext: managedObjectContext,
            tower: tower,
            volumeID: volumeID
        )
        let addPhotosInteractor = makeAddPhotosToOwnAlbumInteractor(
            managedObjectContext: managedObjectContext,
            tower: tower
        )
        return .init(
            dependencies: .init(
                createAlbumInteractor: createAlbumInteractor,
                addPhotosToAlbumInteractor: addPhotosInteractor
            )
        )
    }

    private func makeCreateAlbumInteractor(
        managedObjectContext: NSManagedObjectContext,
        tower: Tower,
        volumeID: VolumeID
    ) -> CreateAlbumInteractor {
        let provider = PhotoRootInfoProvider(
            dependencies: .init(
                managedObjectContext: managedObjectContext,
                storageManager: tower.storage
            )
        )
        return .init(
            dependencies: .init(
                client: tower.client,
                encryptor: Encryptor(),
                signersKitFactory: tower.sessionVault,
                managedObjectContext: managedObjectContext,
                photoRootProvider: provider
            ),
            volumeID: volumeID
        )
    }

    func makeAddPhotosToOwnAlbumInteractor(
        managedObjectContext: NSManagedObjectContext,
        tower: Tower
    ) -> AddPhotosToOwnAlbumInteractor {
        let provider = AlbumKeyProvider(context: managedObjectContext)
        return .init(
            dependencies: .init(
                albumKeyProvider: provider,
                client: tower.client,
                context: managedObjectContext,
                encryptor: Encryptor(),
                infoReader: NodeCryptoMaterialReader(moc: managedObjectContext, signersKitFactory: tower.sessionVault),
                signersKitFactory: tower.sessionVault,
                metadataResource: PDPhotosFactory().makeRemoteMetadataFetchRepository(tower: tower, managedObjectContext: managedObjectContext)
            )
        )
    }

    func makeDeleteAlbumController(
        managedObjectContext: NSManagedObjectContext,
        tower: Tower
    ) -> DeleteAlbumController {
        let interactor = DeleteAlbumInteractor(
            dependencies: .init(
                client: tower.client,
                managedObjectContext: managedObjectContext
            )
        )
        let infoReader = NodeCryptoMaterialReader(moc: managedObjectContext, signersKitFactory: tower.sessionVault)
        let transferrer = MultiplePhotoTransfer(
            client: tower.client,
            infoReader: infoReader,
            linksFactory: MultipleMovingNodeLinkFactory(infoReader: infoReader, moc: managedObjectContext),
            localUpdater: MovedNodesUpdateRepository(moc: managedObjectContext, parentIDFetcher: tower.parentIDFetcher),
            moc: managedObjectContext
        )
        let provider = PhotoRootInfoProvider(
            dependencies: .init(
                managedObjectContext: managedObjectContext,
                storageManager: tower.storage
            )
        )
        let duplicatesCheck = SimplePhotoDuplicatesCheckInteractor(
            dependencies: .init(
                context: managedObjectContext,
                encryptionResource: Encryptor(),
                repository: tower.client,
                rootReader: NodeWithHashKeyReader()
            )
        )
        return .init(
            dependencies: .init(
                context: managedObjectContext,
                duplicatesCheckInteractor: duplicatesCheck,
                interactor: interactor,
                multipleNodeTransferrer: transferrer,
                photoRootProvider: provider,
                errorParser: RemoteDeleteAlbumErrorParser()
            )
        )
    }

    func makeInvitationsView(controller: AlbumInvitationsControllerProtocol, coordinator: AlbumGalleryCoordinatorProtocol) -> some View {
        let viewModel = AlbumInvitationsViewModel(controller: controller, coordinator: coordinator)
        return AlbumInvitationsView(viewModel: viewModel)
    }

    func makeInvitationsController(container: PendingInvitationsContainer) -> AlbumInvitationsControllerProtocol {
        let statusInteractor = container.makePendingInvitationsStatusInteractor()
        let interactor = AlbumInvitationsInteractor(interactor: statusInteractor)
        let facade = AlbumInvitationsFacade(interactor: interactor)
        return AlbumInvitationsController(facade: facade)
    }
}
