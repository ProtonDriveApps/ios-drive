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
import PDClient
import Combine

struct PhotosFactory {
    func makeSettingsController(localSettings: LocalSettings) -> PhotoBackupSettingsController {
        LocalPhotoBackupSettingsController(localSettings: localSettings)
    }

    func makeAuthorizationController() -> PhotoLibraryAuthorizationController {
        LocalPhotoLibraryAuthorizationController(resource: LocalPhotoLibraryAuthorizationResource())
    }

    func makePhotosBootstrapController(tower: Tower) -> PhotosBootstrapController {
        let observer = makePhotoSharesObserver(tower: tower)
        let local = makeLocalPhotosRootDataSource(observer: observer)
        let remoteFetching = RemoteFetchingPhotosRootDataSource(storage: tower.storage, photoShareListing: tower.client)
        let remoteCreating = RemoteCreatingPhotosRootDataSource(storage: tower.storage, sessionVault: tower.sessionVault, photoShareCreator: tower.client)
        
        let interactor = PhotoShareBootstrapInteractor(
            dataSource: FallbackPhotosShareDataSource(
                primary: local,
                secondary: FallbackPhotosShareDataSource(
                    primary: remoteFetching,
                    secondary: remoteCreating
                )
            )
        )
        let repository = FetchResultControllerObserverPhotosBootstrapRepository(observer: observer)
        return MonitoringBootstrapController(interactor: interactor, repository: repository)
    }

    func makePhotoSharesObserver(tower: Tower) -> FetchedResultsControllerObserver<PDCore.Share> {
        FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPhotoShares())
    }

    func makeLocalPhotosRootDataSource(observer: FetchedResultsControllerObserver<PDCore.Share>) -> PhotosShareDataSource {
        LocalPhotosRootDataSource(observer: observer)
    }

    func makeAssetsController(constraintsController: PhotoBackupConstraintsController, interactor: PhotoLibraryAssetsInteractor) -> PhotoAssetsController {
        LocalPhotoAssetsController(constraintsController: constraintsController, interactor: interactor)
    }

    func makeBackupController(settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, bootstrapController: PhotosBootstrapController) -> PhotosBackupController {
        return DrivePhotosBackupController(authorizationController: authorizationController, settingsController: settingsController, bootstrapController: bootstrapController)
    }

    func makeLoadController(backupController: PhotosBackupController, assetsInteractor: PhotoLibraryAssetsInteractor, tower: Tower, progressRepository: PhotoLibraryLoadProgressRepository) -> PhotoLibraryLoadController {
        let mappingResource = LocalPhotoLibraryMappingResource()
        let identifiersInteractor = LocalFilteredPhotoIdentifiersInteractor(
            resource: DatabaseFilteredPhotoIdentifiersResource(storage: tower.storage, policy: PhotoIdentifiersFilterPolicy()),
            assetsInteractor: assetsInteractor,
            progressRepository: progressRepository
        )
        let interactor = LocalPhotoLibraryLoadInteractor(identifiersInteractor: identifiersInteractor, resources: [
            LocalPhotoLibraryFetchResource(mappingResource: mappingResource),
            LocalPhotoLibraryUpdateResource(mappingResource: mappingResource),
        ], progressRepository: progressRepository)
        return LocalPhotoLibraryLoadController(backupController: backupController, interactor: interactor)
    }

    func makeAssetsOperationInteractor(queueResource: PhotoLibraryAssetsQueueResource) -> OperationInteractor {
        PhotoLibraryAssetsOperationInteractor(resource: queueResource)
    }

    func makeAssetsQueueResource() -> PhotoLibraryAssetsQueueResource {
        let contentResource = LocalPhotoLibraryFileContentResource(digestBuilderFactory: { SHA1DigestBuilder() })
        let assetFactory = LocalPhotoAssetFactory(nameStrategy: LocalPhotoLibraryFilenameStrategy())
        let assetResource = LocalPhotoLibraryAssetResource(contentResource: contentResource, assetFactory: assetFactory, exifResource: LocalPhotoLibraryExifResource())
        let nameResource = PHAssetNameResource()
        let plainCompoundResource = PhotoLibraryPlainCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let livePhotoResource = PhotoLibraryLivePhotoCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let burstResource = PhotoLibraryBurstCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let resource = LocalPhotoLibraryAssetsResource(plainResource: plainCompoundResource, livePhotoResource: livePhotoResource, burstResource: burstResource)
        return LocalPhotoLibraryAssetsQueueResource(resource: resource)
    }

    func makeAssetsInteractor(observer: FetchedResultsControllerObserver<PDCore.Share>, queueResource: PhotoLibraryAssetsQueueResource, tower: Tower, progressRepository: PhotoLibraryLoadProgressRepository) -> LocalPhotoLibraryAssetsInteractor {
        let datasource = LocalPhotosRootFolderDatasource(observer: observer)
        let repository = InMemoryCachingEncryptingPhotosRootRepository(datasource: datasource)
        let photoImporter = CoreDataPhotoImporter(moc: tower.storage.backgroundContext, rootRepository: repository, signersKitFactory: tower.sessionVault)
        let compoundImporter = CompoundPhotoCompoundImporter(importer: photoImporter, moc: tower.storage.backgroundContext)
        let edditedPhotoImporter = EditedAssetPhotoImportInteractor(photoCompoundImporter: compoundImporter)
        let filteredCompoundsInteractor = LocalFilteredPhotoCompoundsInteractor(
            resource: DatabaseFilteredPhotoCompoundsResource(storage: tower.storage),
            importInteractor: edditedPhotoImporter,
            progressRepository: progressRepository
        )
        return LocalPhotoLibraryAssetsInteractor(resource: queueResource, compoundsInteractor: filteredCompoundsInteractor, progressRepository: progressRepository)
    }

    func makeNetworkConstraintController(backupController: PhotosBackupController, settingsController: PhotoBackupSettingsController) -> PhotoBackupConstraintController {
        let networkInteractor = ConnectedNetworkStateInteractor(resource: MonitoringNetworkStateResource())
        return PhotoBackupNetworkController(backupController: backupController, settingsController: settingsController, interactor: networkInteractor)
    }

    func makePhotosBackupUploadAvailableController(backupController: PhotosBackupController, networkConstraintController: PhotoBackupConstraintController) -> PhotosBackupUploadAvailableController {
        LocalPhotosBackupUploadAvailableController(backupController: backupController, networkConstraintController: networkConstraintController)
    }

    func makeConstraintsController(backupController: PhotosBackupController, settingsController: PhotoBackupSettingsController, networkConstraintController: PhotoBackupConstraintController) -> PhotoBackupConstraintsController {
        let resource = LocalPhotoAssetsStorageSizeResource(updateResource: LocalFolderUpdateResource(), sizeResource: LocalFolderSizeResource())
        let interactor = LocalPhotoAssetsStorageConstraintInteractor(resource: resource)
        let storageController = PhotoAssetsStorageController(backupController: backupController, interactor: interactor)
        return LocalPhotoBackupConstraintsController(storageController: storageController, networkController: networkConstraintController)
    }
    
    func makePhotoUploader(tower: Tower, isAvailableController: PhotosBackupUploadAvailableController) -> PhotoUploader {
        let photosObserver = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToUploadingPhotos())
        let fileUploadFactory = PhotosUploadOperationsProviderFactory(storage: tower.storage, cloudSlot: tower.cloudSlot, sessionVault: tower.sessionVault, apiService: tower.api)
        return PhotoUploader(photosRepository: photosObserver, photoUploadAvailabilityController: isAvailableController, operationsProvider: fileUploadFactory.make(), storage: tower.storage, sessionVault: tower.sessionVault, moc: tower.storage.backgroundContext)
    }

    func makeBackupProgressRepository() -> PhotoLibraryLoadProgressActionRepository & PhotoLibraryLoadProgressRepository {
        LocalPhotoLibraryLoadProgressActionRepository()
    }

    func makeBackupProgressController(tower: Tower, repository: PhotoLibraryLoadProgressActionRepository) -> PhotosBackupProgressController {
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPrimaryUploadingPhotos(moc: tower.storage.backgroundContext))
        let libraryLoadController = LocalPhotoLibraryLoadProgressController(interactor: repository)
        let uploadsRepository = DatabasePhotoUploadsRepository(observer: observer)
        let uploadsController = LocalPhotosUploadsProgressController(repository: uploadsRepository)
        return LocalPhotosBackupProgressController(libraryLoadController: libraryLoadController, uploadsController: uploadsController)
    }
}
