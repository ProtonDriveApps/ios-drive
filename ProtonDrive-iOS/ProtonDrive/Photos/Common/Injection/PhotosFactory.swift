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

struct PhotosFactory {
    func makeAssetsController(interactor: PhotoLibraryAssetsInteractor) -> PhotoAssetsController {
        LocalPhotoAssetsController(interactor: interactor)
    }

    func makeLoadController(localSettings: LocalSettings, assetsInteractor: PhotoLibraryAssetsInteractor) -> PhotoLibraryLoadController {
        let authorizationController = LocalPhotoLibraryAuthorizationController(resource: LocalPhotoLibraryAuthorizationResource())
        let settingsController = LocalPhotoBackupSettingsController(localSettings: localSettings)
        let mappingResource = LocalPhotoLibraryMappingResource()
        let interactor = LocalPhotoLibraryLoadInteractor(assetsInteractor: assetsInteractor, resources: [
            LocalPhotoLibraryFetchResource(mappingResource: mappingResource),
            LocalPhotoLibraryUpdateResource(mappingResource: mappingResource),
        ])
        return LocalPhotoLibraryLoadController(
            authorizationController: authorizationController,
            settingsController: settingsController,
            interactor: interactor
        )
    }

    func makeAssetsOperationInteractor(queueResource: PhotoLibraryAssetsQueueResource) -> OperationInteractor {
        PhotoLibraryAssetsOperationInteractor(resource: queueResource)
    }

    func makeAssetsQueueResource() -> PhotoLibraryAssetsQueueResource {
        let contentResource = LocalPhotoLibraryFileContentResource(digestBuilderFactory: { SHA1DigestBuilder() })
        let assetFactory = LocalPhotoAssetFactory(nameStrategy: LocalPhotoLibraryFilenameStrategy())
        let assetResource = LocalPhotoLibraryAssetResource(contentResource: contentResource, assetFactory: assetFactory)
        let nameResource = PHAssetNameResource()
        let plainCompoundResource = PhotoLibraryPlainCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let livePhotoResource = PhotoLibraryLivePhotoCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let burstResource = PhotoLibraryBurstCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let resource = LocalPhotoLibraryAssetsResource(plainResource: plainCompoundResource, livePhotoResource: livePhotoResource, burstResource: burstResource)
        return LocalPhotoLibraryAssetsQueueResource(resource: resource)
    }

    func makeAssetsInteractor(queueResource: PhotoLibraryAssetsQueueResource) -> LocalPhotoLibraryAssetsInteractor {
        return LocalPhotoLibraryAssetsInteractor(resource: queueResource, policy: DummyPhotoLibraryFilterPolicy(), importInteractor: DummyPhotoImportInteractor())
    }
}
