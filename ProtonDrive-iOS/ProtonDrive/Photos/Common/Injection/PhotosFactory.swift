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

struct PhotosFactory {
    func makeSettingsController(localSettings: LocalSettings) -> PhotoBackupSettingsController {
        LocalPhotoBackupSettingsController(localSettings: localSettings)
    }

    func makeAuthorizationController() -> PhotoLibraryAuthorizationController {
        LocalPhotoLibraryAuthorizationController(resource: LocalPhotoLibraryAuthorizationResource())
    }

    func makePhotosBootstrapController(tower: Tower) -> PhotosBootstrapController {
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPhotoDevices())
        let local = LocalPhotosRootDataSource(observer: observer)
        let remoteFetching = RemoteFetchingPhotosRootDataSource(storage: tower.storage, photoShareListing: tower.client)
        let remoteCreating = RemoteCreatingPhotosRootDataSource(storage: tower.storage, sessionVault: tower.sessionVault, photoShareCreator: tower.client)
        
        let interactor = DevicePhotosBootstrapInteractor(
            dataSource: FallbackPhotosDeviceDataSource(
                primary: local,
                secondary: FallbackPhotosDeviceDataSource(
                    primary: remoteFetching,
                    secondary: remoteCreating
                )
            )
        )
        let repository = FetchResultControllerObserverPhotosBootstrapRepository(observer: observer)
        
        return MonitoringBootstrapController(interactor: interactor, repository: repository)
    }

    func makeAssetsController(constraintsController: PhotoBackupConstraintsController, interactor: PhotoLibraryAssetsInteractor) -> PhotoAssetsController {
        LocalPhotoAssetsController(constraintsController: constraintsController, interactor: interactor)
    }

    func makeBackupController(settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, bootstrapController: PhotosBootstrapController) -> PhotosBackupController {
        return DrivePhotosBackupController(authorizationController: authorizationController, settingsController: settingsController, bootstrapController: bootstrapController)
    }

    func makeLoadController(backupController: PhotosBackupController, assetsInteractor: PhotoLibraryAssetsInteractor, tower: Tower) -> PhotoLibraryLoadController {
        let mappingResource = LocalPhotoLibraryMappingResource()
        let identifiersInteractor = LocalFilteredPhotoIdentifiersInteractor(
            resource: DatabaseFilteredPhotoIdentifiersResource(storage: tower.storage, policy: PhotoIdentifiersFilterPolicy()),
            assetsInteractor: assetsInteractor
        )
        let interactor = LocalPhotoLibraryLoadInteractor(identifiersInteractor: identifiersInteractor, resources: [
            LocalPhotoLibraryFetchResource(mappingResource: mappingResource),
            LocalPhotoLibraryUpdateResource(mappingResource: mappingResource),
        ])
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

    func makeAssetsInteractor(queueResource: PhotoLibraryAssetsQueueResource, tower: Tower) -> LocalPhotoLibraryAssetsInteractor {
        let filteredCompoundsInteractor = LocalFilteredPhotoCompoundsInteractor(
            resource: DatabaseFilteredPhotoCompoundsResource(storage: tower.storage),
            importInteractor: DummyPhotoImportInteractor()
        )
        return LocalPhotoLibraryAssetsInteractor(resource: queueResource, compoundsInteractor: filteredCompoundsInteractor)
    }

    func makeConstraintsController(backupController: PhotosBackupController, settingsController: PhotoBackupSettingsController) -> PhotoBackupConstraintsController {
        let resource = LocalPhotoAssetsStorageSizeResource(updateResource: LocalFolderUpdateResource(), sizeResource: LocalFolderSizeResource())
        let interactor = LocalPhotoAssetsStorageConstraintInteractor(resource: resource)
        let storageController = PhotoAssetsStorageController(backupController: backupController, interactor: interactor)
        let networkInteractor = ConnectedNetworkStateInteractor(resource: MonitoringNetworkStateResource())
        let networkController = PhotoBackupNetworkController(backupController: backupController, settingsController: settingsController, interactor: networkInteractor)
        return LocalPhotoBackupConstraintsController(storageController: storageController, networkController: networkController)
    }
}

// TODO: replace with real implementation
final class DummyPhotoImportInteractor: PhotoImportInteractor {
    func execute(with compounds: [PhotoAssetCompound]) {}
}
