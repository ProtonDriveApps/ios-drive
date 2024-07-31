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

final class PhotosProcessingContainer {
    struct Dependencies {
        let tower: Tower
        let backupController: PhotosBackupController
        let constraintsController: PhotoBackupConstraintsController
        let identifiersController: PhotoLibraryIdentifiersController
        let progressRepository: PhotoLibraryLoadProgressRepository
        let failedItemsResource: DeletedPhotosIdentifierStoreResource
        let photoSkippableCache: PhotosSkippableCache
        let settingsController: PhotoBackupSettingsController
        let computationalAvailabilityController: ComputationalAvailabilityController
        let circuitBreaker: CircuitBreakerController
        let scanningMeasurementRepository: DurationMeasurementRepository
        let duplicatesMeasurementRepository: DurationMeasurementRepository
        let photoSharesObserver: FetchedResultsControllerObserver<PDCore.Share>
    }

    let processingController: PhotosProcessingController

    init(dependencies: Dependencies) {
        let factory = PhotosProcessingFactory()
        processingController = factory.makeProcessingController(dependencies: dependencies)
    }
}
