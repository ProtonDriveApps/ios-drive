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
    // swiftlint:disable:next function_parameter_count
    func makeProcessingController(tower: Tower, identifiersController: PhotoLibraryIdentifiersController, backupController: PhotosBackupController, constraintsController: PhotoBackupConstraintsController, progressRepository: PhotoLibraryLoadProgressRepository, failedIdentifiersResource: DeletedPhotosIdentifierStoreResource, photoSkippableCache: PhotosSkippableCache, settingsController: PhotoBackupSettingsController, computationalAvailabilityController: ComputationalAvailabilityController, circuitBreaker: CircuitBreakerController, duplicatesMeasurementRepository: DurationMeasurementRepository, scanningMeasurementRepository: DurationMeasurementRepository) -> PhotosProcessingController {
        let factory = makeOperationsFactory(tower: tower, progressRepository: progressRepository, failedIdentifiersResource: failedIdentifiersResource, photoSkippableCache: photoSkippableCache, settingsController: settingsController, circuitBreaker: circuitBreaker, duplicatesMeasurementRepository: duplicatesMeasurementRepository, scanningMeasurementRepository: scanningMeasurementRepository)
        let processingResource = ConcretePhotosProcessingQueueResource(factory: factory)
        let managedObjectContext = tower.storage.newBackgroundContext()
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPrimaryUploadingPhotos(moc: managedObjectContext))
        let repository = CoreDataPhotosUploadingCountRepository(observer: observer)
        let batchAvailableController = ConcretePhotosProcessingBatchAvailableController(repository: repository)
        let availableController = ConcretePhotosProcessingAvailableController(
            backupController: backupController,
            constraintsController: constraintsController,
            computationalAvailabilityController: computationalAvailabilityController
        )
        return ConcretePhotosProcessingController(
            identifiersController: identifiersController,
            backupController: backupController,
            availableController: availableController,
            processingResource: processingResource,
            batchAvailableController: batchAvailableController,
            cleanUpController: tower.cleanUpController
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func makeOperationsFactory(tower: Tower, progressRepository: PhotoLibraryLoadProgressRepository, failedIdentifiersResource: DeletedPhotosIdentifierStoreResource, photoSkippableCache: PhotosSkippableCache, settingsController: PhotoBackupSettingsController, circuitBreaker: CircuitBreakerController, duplicatesMeasurementRepository: DurationMeasurementRepository, scanningMeasurementRepository: DurationMeasurementRepository) -> PhotosProcessingOperationsFactory {
        return ConcretePhotosProcessingOperationsFactory(
            filterByIdResource: DatabasePhotosFilterByIdResource(storage: tower.storage, policy: PhotoIdentifiersFilterPolicy()),
            assetsResource: makeAssetsResource(settingsController: settingsController),
            conflictInteractor: PhotoRemoteFilterFactory().makeRemoteFilterInteractor(tower: tower, circuitBreaker: circuitBreaker),
            photosImporter: PhotoImportFactory().makeImporter(tower: tower),
            progressRepository: progressRepository, 
            failedIdentifiersResource: failedIdentifiersResource,
            photoSkippableCache: photoSkippableCache,
            storageSizeLimit: Constants.photosAssetsMaximalFolderSize,
            duplicatesMeasurementRepository: duplicatesMeasurementRepository,
            scanningMeasurementRepository: scanningMeasurementRepository
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
        let portraitCompoundResource = PhotoLibraryPortraitCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let burstResource = PhotoLibraryBurstCompoundResource(assetResource: assetResource, nameResource: nameResource)
        let optionsFactory = PHFetchOptionsFactory(supportedMediaTypes: settingsController.supportedMediaTypes, notOlderThan: settingsController.notOlderThan)
        return LocalPhotoLibraryAssetsResource(plainResource: plainCompoundResource, livePhotoResource: livePhotoResource, portraitPhotoResource: portraitCompoundResource, burstResource: burstResource, optionsFactory: optionsFactory, mappingResource: LocalPhotoLibraryMappingResource())
    }
}
