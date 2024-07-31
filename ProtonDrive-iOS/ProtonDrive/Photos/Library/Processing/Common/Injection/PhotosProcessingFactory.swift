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

import Foundation
import PDCore

struct PhotosProcessingFactory {
    func makeProcessingController(dependencies: PhotosProcessingContainer.Dependencies) -> PhotosProcessingController {
        let factory = makeOperationsFactory(dependencies: dependencies)
        let processingResource = ConcretePhotosProcessingQueueResource(factory: factory)
        let managedObjectContext = dependencies.tower.storage.newBackgroundContext()
        let observer = FetchedResultsControllerObserver(controller: dependencies.tower.storage.subscriptionToPrimaryUploadingPhotos(moc: managedObjectContext))
        let repository = CoreDataPhotosUploadingCountRepository(observer: observer)
        let batchAvailableController = ConcretePhotosProcessingBatchAvailableController(repository: repository)
        let availableController = ConcretePhotosProcessingAvailableController(
            backupController: dependencies.backupController,
            constraintsController: dependencies.constraintsController,
            computationalAvailabilityController: dependencies.computationalAvailabilityController
        )
        return ConcretePhotosProcessingController(
            identifiersController: dependencies.identifiersController,
            backupController: dependencies.backupController,
            availableController: availableController,
            processingResource: processingResource,
            batchAvailableController: batchAvailableController,
            cleanUpController: dependencies.tower.cleanUpController
        )
    }

    private func makeOperationsFactory(dependencies: PhotosProcessingContainer.Dependencies) -> PhotosProcessingOperationsFactory {
        return ConcretePhotosProcessingOperationsFactory(
            filterByIdResource: DatabasePhotosFilterByIdResource(storage: dependencies.tower.storage, policy: PhotoIdentifiersFilterPolicy()),
            assetsResource: makeAssetsResource(settingsController: dependencies.settingsController),
            conflictInteractor: PhotoRemoteFilterFactory().makeRemoteFilterInteractor(tower: dependencies.tower, circuitBreaker: dependencies.circuitBreaker, photoSharesObserver: dependencies.photoSharesObserver),
            photosImporter: PhotoImportFactory().makeImporter(tower: dependencies.tower),
            progressRepository: dependencies.progressRepository,
            failedIdentifiersResource: dependencies.failedItemsResource,
            photoSkippableCache: dependencies.photoSkippableCache,
            storageSizeLimit: Constants.photosAssetsMaximalFolderSize,
            duplicatesMeasurementRepository: dependencies.duplicatesMeasurementRepository,
            scanningMeasurementRepository: dependencies.scanningMeasurementRepository
        )
    }

    private func makeAssetsResource(settingsController: PhotoBackupSettingsController) -> PhotoLibraryAssetsResource {
        let contentResource = LocalPhotoLibraryFileContentResource()
        let assetFactory = LocalPhotoAssetFactory(nameStrategy: LocalPhotoLibraryFilenameStrategy())
        // We don't upload exif until the format is aligned. `CoreImagePhotoLibraryExifResource(parser: CoreImagePhotoLibraryExifParser())`
//        let exifResource = CoreImagePhotoLibraryExifResource(parser: CoreImagePhotoLibraryExifParser())
        let exifResource = PartialPhotoLibraryExifResource()
        let assetResource = LocalPhotoLibraryAssetResource(contentResource: contentResource, assetFactory: assetFactory, exifResource: exifResource)
        let nameResource = PHAssetNameResource()
        let liveCompoundResource = ConcretePhotoLibraryLivePairCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let livePhotoResource = PhotoLibraryLivePhotoCompoundResource(liveCompoundResource: liveCompoundResource)
        let plainCompoundResource = PhotoLibraryPlainCompoundResource(livePhotoResource: livePhotoResource, assetResource: assetResource, nameResource: nameResource)
        let portraitCompoundResource = PhotoLibraryPortraitCompoundResource(assetResource: assetResource, nameResource: nameResource, plainResource: plainCompoundResource)
        let cinematicVideoCompoundResource = PhotoLibraryCinematicVideoCompoundResource(assetResource: assetResource, nameResource: nameResource, plainResource: plainCompoundResource)
        let burstResource = PhotoLibraryBurstCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let optionsFactory = PHFetchOptionsFactory(supportedMediaTypes: settingsController.supportedMediaTypes, notOlderThan: settingsController.notOlderThan)
        return LocalPhotoLibraryAssetsResource(plainResource: plainCompoundResource, livePhotoResource: livePhotoResource, portraitPhotoResource: portraitCompoundResource, cinematicVideoResource: cinematicVideoCompoundResource, burstResource: burstResource, optionsFactory: optionsFactory, mappingResource: LocalPhotoLibraryMappingResource())
    }
}
