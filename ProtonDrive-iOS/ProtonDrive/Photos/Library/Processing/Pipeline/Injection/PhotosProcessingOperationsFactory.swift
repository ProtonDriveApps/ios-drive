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

protocol PhotosProcessingOperationsFactory {
    func makeContext(with identifiers: Set<PhotoIdentifier>) -> PhotosProcessingContext
    func makeOperations(with context: PhotosProcessingContext) -> [Operation]
}

final class ConcretePhotosProcessingOperationsFactory: PhotosProcessingOperationsFactory {
    private let filterByIdResource: PhotosFilterByIdResource
    private let assetsResource: PhotoLibraryAssetsResource
    private let conflictInteractor: PhotoAssetCompoundsConflictInteractor
    private let photosImporter: PhotoCompoundImporter
    private let progressRepository: PhotoLibraryLoadProgressRepository
    private let failedIdentifiersResource: DeletedPhotosIdentifierStoreResource
    private let photoSkippableCache: PhotosSkippableCache
    private let duplicatesMeasurementRepository: DurationMeasurementRepository
    private let scanningMeasurementRepository: DurationMeasurementRepository
    private let storageSizeLimit: Int

    init(filterByIdResource: PhotosFilterByIdResource, assetsResource: PhotoLibraryAssetsResource, conflictInteractor: PhotoAssetCompoundsConflictInteractor, photosImporter: PhotoCompoundImporter, progressRepository: PhotoLibraryLoadProgressRepository, failedIdentifiersResource: DeletedPhotosIdentifierStoreResource, photoSkippableCache: PhotosSkippableCache, storageSizeLimit: Int, duplicatesMeasurementRepository: DurationMeasurementRepository, scanningMeasurementRepository: DurationMeasurementRepository) {
        self.filterByIdResource = filterByIdResource
        self.assetsResource = assetsResource
        self.conflictInteractor = conflictInteractor
        self.photosImporter = photosImporter
        self.progressRepository = progressRepository
        self.failedIdentifiersResource = failedIdentifiersResource
        self.photoSkippableCache = photoSkippableCache
        self.storageSizeLimit = storageSizeLimit
        self.duplicatesMeasurementRepository = duplicatesMeasurementRepository
        self.scanningMeasurementRepository = scanningMeasurementRepository
    }

    func makeContext(with identifiers: Set<PhotoIdentifier>) -> PhotosProcessingContext {
        ConcretePhotosProcessingContext(initialIdentifiers: identifiers)
    }

    func makeOperations(with context: PhotosProcessingContext) -> [Operation] {
        let filterSkippableInteractor = PhotosFilterSkippableInteractor(context: context, skippableCache: photoSkippableCache)
        let filterByIdInteractor = PhotosFilterByIdInteractor(context: context, resource: filterByIdResource, measurementRepository: scanningMeasurementRepository)
        let assetsInteractor = PhotosAssetsInteractor(context: context, resource: assetsResource, sizeResource: ConcretePhotoCompoundsSizeResource(), errorPolicy: FoundationPhotoAssetErrorPolicy(), errorMappingPolicy: FoundationPhotosAssetsErrorMappingPolicy(), skippableCache: photoSkippableCache, sizeLimit: storageSizeLimit, measurementRepository: scanningMeasurementRepository)
        let duplicateCheckInteractor = PhotosDuplicatesCheckInteractor(context: context, interactor: conflictInteractor, skippableCache: photoSkippableCache, measurementRepository: duplicatesMeasurementRepository)
        // Need to execute import and finish in a atomically to avoid race conditions.
        let finishInteractor = AggregatedAsynchronousExecution(executions: [
            PhotosImportInteractor(context: context, importer: photosImporter),
            PhotosProcessingFinishInteractor(context: context, progressRepository: progressRepository, localStorageResource: LocalFileStorageResource(), failedIdentifiersResource: failedIdentifiersResource)
        ])

        let filterSkippableOperation = AsynchronousExecutionOperation(execution: filterSkippableInteractor)
        let filterByIdOperation = AsynchronousExecutionOperation(execution: filterByIdInteractor)
        let assetsOperation = AsynchronousExecutionOperation(execution: assetsInteractor)
        let duplicateCheckOperation = AsynchronousExecutionOperation(execution: duplicateCheckInteractor)
        let finishOperation = AsynchronousExecutionOperation(execution: finishInteractor)

        filterByIdOperation.addDependency(filterSkippableOperation)
        assetsOperation.addDependency(filterByIdOperation)
        duplicateCheckOperation.addDependency(assetsOperation)
        finishOperation.addDependency(duplicateCheckOperation)
        return [filterSkippableOperation, filterByIdOperation, assetsOperation, duplicateCheckOperation, finishOperation]
    }
}
