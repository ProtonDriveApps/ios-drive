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
import PDContacts

struct PDPhotosFactory {
    func makeRootViewModel() -> RootViewModel {
        RootViewModel()
    }

    func makeSelectionController() -> PhotosSelectionController {
        LocalPhotosSelectionController()
    }

    func makeMetadataController(tower: Tower, managedObjectContext: NSManagedObjectContext) -> MetadataControllerProtocol {
        let repository = makeRemoteMetadataFetchRepository(tower: tower, managedObjectContext: managedObjectContext)
        return MetadataController(debounceResource: ScheduleDebounceResource(), repository: repository)
    }

    func makeRemoteMetadataFetchRepository(tower: Tower, managedObjectContext: NSManagedObjectContext) -> RemoteMetadataFetchRepository {
        let cacher = CoreDataMetadataCache(store: tower.storage, context: managedObjectContext)
        let repository = RemoteMetadataFetchRepository(cacher: cacher, client: tower.client)
        return repository
    }

    func makeThumbnailsContainer(
        tower: Tower,
        metadataController: MetadataControllerProtocol,
        performanceMetricsController: PerformanceMetricsControllerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) -> ThumbnailsControllersContainer {
        ThumbnailsControllersContainer(dependencies: ThumbnailsControllersContainer.Dependencies(
            tower: tower,
            metadataController: metadataController,
            performanceMetricsController: performanceMetricsController,
            featureFlagsController: featureFlagsController
        ))
    }

    func makeLocalAlbumListController(
        context: NSManagedObjectContext,
        storageManger: StorageManager,
        streamConfiguration: PhotoStreamConfiguration
    ) -> LocalAlbumListController {
        return .init(
            dependencies: .init(
                managedObjectContext: context,
                observerFactory: AlbumListObserverFactory(
                    managedObjectContext: context,
                    storageManager: storageManger,
                    streamConfiguration: streamConfiguration
                )
            )
        )
    }

    func makeRemoteAlbumFetchController(
        context: NSManagedObjectContext,
        featureFlagsController: FeatureFlagsControllerProtocol,
        tower: Tower,
        streamConfiguration: PhotoStreamConfiguration,
        contactsManager: ContactsManagerProtocol
    ) -> RemoteAlbumFetchController {
        if streamConfiguration.volumeId.isEmpty {
            Log.error("makeRemoteAlbumFetchController but stream volumeID is nil", error: nil, domain: .albums)
        }
        let cache = CoredataSharedWithMeLinkMetadataCache(storage: tower.storage)
        let retriever = SharedWithMeLinksMetadataRetriever(
            remoteShareDataSource: tower.client,
            remoteLinksDataSource: tower.client,
            sharedWithMeLinksCache: cache,
            contactsController: ContactsController(contactsManager: contactsManager),
            keysVault: tower.sessionVault
        )
        let starter = makeSharedWithMeAlbumStarter(
            context: context,
            featureFlagsController: featureFlagsController,
            tower: tower,
            streamConfiguration: streamConfiguration
        )
        return .init(
            dependencies: .init(
                interactor: makeListAllAlbumInteractor(client: tower.client, volumeID: streamConfiguration.volumeId),
                photoVolumeID: streamConfiguration.volumeId,
                retriever: retriever,
                starter: starter,
                storeAlbumListingsRepository: CoreDataStoreAlbumListingsRepository(managedObjectContext: context),
                volumeIDsController: tower.sharedVolumeIdsController
            )
        )
    }

    private func makeListAllAlbumInteractor(client: PhotoListAlbumsAPIService, volumeID: String) -> ListAllAlbumInteractor {
        .init(
            listOwnedAlbumInteractor: ListOwnedAlbumInteractor(client: client, photoVolumeID: volumeID),
            listSharedWithMeAlbumInteractor: ListSharedWithMeAlbumInteractor(client: client)
        )
    }

    private func makeSharedWithMeAlbumStarter(
        context: NSManagedObjectContext,
        featureFlagsController: FeatureFlagsControllerProtocol,
        tower: Tower,
        streamConfiguration: PhotoStreamConfiguration
    ) -> SharedWithMeAlbumStarter {
        let controller = SharedVolumesEventsController(
            featureFlagsController: featureFlagsController,
            eventsManager: tower,
            volumeIdsController: tower.sharedVolumeIdsController
        )
        return SharedWithMeAlbumStarter(
            dependencies: .init(
                context: context,
                storage: tower.storage,
                sharedVolumesEventsController: controller,
                streamConfiguration: streamConfiguration
            )
        )
    }

    func makeBootstrapController(
        tower: Tower,
        featureFlagsController: FeatureFlagsControllerProtocol,
        shareCreationResource: PhotoShareCreationFinishResource,
        errorController: ErrorSetControllerProtocol
    ) -> PhotoVolumeBootstrapControllerProtocol {
        let managedObjectContext = tower.storage.newBackgroundContext()
        let localResource = LocalPhotosVolumeFetchResource(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let bootstrapResource = RemotePhotoVolumeBootstrapResource(sharesListing: tower.client, bootstrapClient: tower.client, managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let remoteFetchResource = RemotePhotosVolumeFetchResource(bootstrapResource: bootstrapResource, client: tower.client)
        let createInteractor = CreatePhotoVolumeInteractor(
            client: tower.client,
            clientUIDProvider: tower.sessionVault,
            context: managedObjectContext,
            encryptor: Encryptor(),
            localSettings: tower.localSettings,
            shareCreationResource: shareCreationResource
        )
        let legacyShareDeleteRepository = LegacyPhotoShareDeleteRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let interactor = PhotoVolumeBootstrapInteractor(
            localResource: localResource,
            remoteFetchResource: remoteFetchResource,
            createInteractor: createInteractor,
            signersKitFactory: tower.sessionVault,
            eventsStartResource: PhotoVolumeEventsStartResource(tower: tower),
            legacyShareDeleteRepository: legacyShareDeleteRepository
        )
        let facade = AsynchronousPhotosBoostrapFacade(interactor: interactor)
        return PhotoVolumeBootstrapController(
            facade: facade,
            featureFlagsController: featureFlagsController,
            errorController: errorController
        )
    }
}
