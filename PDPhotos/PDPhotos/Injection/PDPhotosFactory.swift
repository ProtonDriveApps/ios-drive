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

    func makeThumbnailsContainer(tower: Tower, metadataController: MetadataControllerProtocol) -> ThumbnailsControllersContainer {
        ThumbnailsControllersContainer(dependencies: ThumbnailsControllersContainer.Dependencies(
            tower: tower,
            metadataController: metadataController
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
        streamConfiguration: PhotoStreamConfiguration
    ) -> RemoteAlbumFetchController {
        if streamConfiguration.volumeId.isEmpty {
            Log.error("makeRemoteAlbumFetchController but stream volumeID is nil", error: nil, domain: .albums)
        }
        let cache = CoredataSharedWithMeLinkMetadataCache(storage: tower.storage)
        let retriever = SharedWithMeLinksMetadataRetriever(
            remoteShareDataSource: tower.client,
            remoteLinksDataSource: tower.client,
            sharedWithMeLinksCache: cache
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
                storeAlbumListingsRepository: CoreDataStoreAlbumListingsRepository(managedObjectContext: context)
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
        migrationController: PhotoVolumeMigrationControllerProtocol,
        tower: Tower,
        featureFlagsController: FeatureFlagsControllerProtocol,
        shareCreationResource: PhotoShareCreationFinishResource,
        errorController: ErrorSetControllerProtocol
    ) -> PhotoVolumeBootstrapControllerProtocol {
        let managedObjectContext = tower.storage.newBackgroundContext()
        let localResource = LocalPhotosVolumeFetchResource(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let bootstrapResource = RemotePhotoVolumeBootstrapResource(sharesListing: tower.client, bootstrapClient: tower.client, managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let legacyShareFetchResource = RemoteFetchingPhotosRootDataSource(storage: tower.storage, photoShareListing: tower.client)
        let remoteFetchResource = RemotePhotosVolumeFetchResource(storageManager: tower.storage, photoShareListing: tower.client, bootstrapResource: bootstrapResource, client: tower.client, legacyShareFetchResource: legacyShareFetchResource)
        let createInteractor = CreatePhotoVolumeInteractor(client: tower.client, context: managedObjectContext, encryptor: Encryptor(), shareCreationResource: shareCreationResource)
        let migrationStatusInteractor = PhotoVolumeMigrationStatusInteractor(apiService: tower.client)
        let legacyShareCreateResource = RemoteCreatingPhotosRootDataSource(storage: tower.storage, sessionVault: tower.sessionVault, photoShareCreator: tower.client, finishResource: shareCreationResource)
        let legacyShareDeleteRepository = LegacyPhotoShareDeleteRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let interactor = PhotoVolumeBootstrapInteractor(
            localResource: localResource,
            remoteFetchResource: remoteFetchResource,
            createInteractor: createInteractor,
            migrationStatusInteractor: migrationStatusInteractor,
            signersKitFactory: tower.sessionVault,
            eventsStartResource: PhotoVolumeEventsStartResource(tower: tower),
            legacyShareCreateResource: legacyShareCreateResource,
            legacyShareDeleteRepository: legacyShareDeleteRepository
        )
        let facade = AsynchronousPhotosBoostrapFacade(interactor: interactor)
        return PhotoVolumeBootstrapController(
            migrationController: migrationController,
            facade: facade,
            featureFlagsController: featureFlagsController,
            errorController: errorController
        )
    }

    func makeMigrationSheetAvailableController(tower: Tower) -> MigrationSheetAvailableControllerProtocol {
        #if DEBUG
        if DebugConstants.commandLineContains(flags: [.uiTests, .skipMigrationPopup]) {
            return DisabledMigrationSheetAvailableController()
        }
        #endif
        let factory = MigrationSheetFactory()
        return factory.makeAvailableController(localSettings: tower.localSettings)
    }

    func makeMigrationController(tower: Tower) -> PhotoVolumeMigrationControllerProtocol {
        let managedObjectContext = tower.storage.newBackgroundContext()
        let remoteStartInteractor = PhotoVolumeMigrationRemoteStartInteractor(apiService: tower.client)
        let deleteRepository = LegacyPhotoShareDeleteRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let startInteractor = PhotoVolumeMigrationStartInteractor(remoteStartInteractor: remoteStartInteractor, deleteRepository: deleteRepository)
        let startFacade = AsynchronousPhotoVolumeMigrationStartFacade(interactor: startInteractor)
        let updateInteractor = PhotoVolumeMigrationStatusInteractor(apiService: tower.client)
        let updateFacade = AsynchronousPhotoVolumeMigrationUpdateFacade(interactor: updateInteractor)
        return PhotoVolumeMigrationController(startFacade: startFacade, updateFacade: updateFacade)
    }
}
