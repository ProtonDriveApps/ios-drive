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
import ProtonCoreKeymaker
import ProtonCoreServices
import UIKit
import Combine

final class PhotosContainer {
    struct Dependencies {
        let tower: Tower
        let windowScene: UIWindowScene
        let keymaker: Keymaker
        let networkService: PMAPIService
        let settingsSuite: SettingsStorageSuite
        let extensionStateController: BackgroundTaskStateController
        let photoSkippableCache: PhotosSkippableCache
    }

    private let dependencies: Dependencies
    private let backupController: PhotosBackupController
    private let networkConstraintController: PhotoBackupConstraintController
    private let constraintsController: PhotoBackupConstraintsController
    private let loadController: PhotoLibraryLoadController
    let uploader: PhotoUploader
    let uploadingPhotosRepository: UploadingPrimaryPhotosRepository
    private let uploaderFeeder: PhotoUploaderFeeder
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let bootstrapController: PhotosBootstrapController
    private let backupProgressController: PhotosBackupProgressController
    private let quotaStateController: QuotaStateController
    private let quotaConstraintController: PhotoBackupConstraintController
    private let lockConstraintController: PhotoBackupConstraintController
    private let lockBannerRepository: ScreenLockingBannerRepository
    private let availableSpaceController: PhotosAvailableSpaceController
    private let featureFlagController: PhotoBackupConstraintController
    private let failedPhotosResource: DeletedPhotosIdentifierStoreResource
    private let backupStateController: LocalPhotosBackupStateController
    private let retryTriggerController: PhotoLibraryLoadRetryTriggerController
    private let photoLeftoversCleaner: PhotoLeftoversCleaner
    private let computationalAvailabilityController: ComputationalAvailabilityController
    private let circuitBreakerController: CircuitBreakerController
    #if HAS_QA_FEATURES
    private let memoryLogResource: MemoryHeartbeatLogResource
    #endif
    // Child containers
    lazy var settingsContainer = makeSettingsContainer()
    private let childContainers: [Any]
    private let processingContainer: PhotosProcessingContainer

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let tower = dependencies.tower
        let factory = PhotosFactory()
        let progressRepository = factory.makeBackupProgressRepository()
        let photosMOC = tower.storage.newBackgroundContext()
        let appStateResource = ApplicationRunningStateResourceImpl() // TODO: this object should be used all over the app, there should be just one, move upwards in the dependency graph
        let processingTaskController = ConcreteBackgroundTaskStateController()
        computationalAvailabilityController = factory.makeComputationalAvailabilityController(extensionTaskController: dependencies.extensionStateController, processingTaskController: processingTaskController)
        self.failedPhotosResource = InMemoryDeletedPhotosIdentifierStoreResource()
        let failuresController = LocalPhotosBackupFailuresController(cleanedUploadingStore: failedPhotosResource)
        let libraryProgressController = factory.makeLibraryProgressController(repository: progressRepository)
        authorizationController = factory.makeAuthorizationController()
        settingsController = factory.makeSettingsController(localSettings: tower.localSettings)

        // Telemetry
        let telemetryStorageContainer = PhotosTelemetryStorageContainer(dependencies: PhotosTelemetryStorageContainer.Dependencies(tower: tower, settingsSuite: dependencies.settingsSuite))
        let measurementsFactory = TelemetryMeasurementsFactory()
        let uploadMeasurementRepository = measurementsFactory.makeParallelDurationRepository()
        let scanningMeasurementRepository = measurementsFactory.makeParallelDurationRepository()
        let duplicatesMeasurementRepository = measurementsFactory.makeParallelDurationRepository()
        let throttlingMeasurementRepository = measurementsFactory.makeParallelDurationRepository()
        let uploadDoneNotifier = MainQueuePhotoUploadDoneNotifier()
        //

        bootstrapController = factory.makePhotosBootstrapController(tower: tower, telemetryContainer: telemetryStorageContainer)
        lockConstraintController = factory.makeLockConstraintController(tower: tower, keymaker: dependencies.keymaker)
        backupController = factory.makeBackupController(settingsController: settingsController, authorizationController: authorizationController, bootstrapController: bootstrapController, lockController: lockConstraintController)
        networkConstraintController = factory.makeNetworkConstraintController(backupController: backupController, settingsController: settingsController)
        quotaStateController = factory.makeQuotaStateController(tower: tower)
        quotaConstraintController = factory.makeQuotaConstraintController(quotaStateController: quotaStateController)
        availableSpaceController = factory.makeAvailableSpaceController(tower: tower, backupController: backupController, computationalAvailabilityController: computationalAvailabilityController)
        featureFlagController = factory.makeFeatureFlagController(tower: tower)
        circuitBreakerController = ReactiveCircuitBreakerController()
        constraintsController = factory.makeConstraintsController(tower: tower, backupController: backupController, settingsController: settingsController, networkConstraintController: networkConstraintController, quotaConstraintController: quotaConstraintController, availableSpaceController: availableSpaceController, circuitBreakerController: circuitBreakerController, throttlingMeasurementRepository: throttlingMeasurementRepository)
        let identifiersQueueRepository = InMemoryPhotoLibraryIdentifiersQueueRepository()
        let identifiersController = ConcretePhotoLibraryIdentifiersController(progressController: libraryProgressController, repository: OrderedRemainingPhotoIdentifiersRepository(), identifiersQueueRepository: identifiersQueueRepository)
        retryTriggerController = ConcretePhotoLibraryLoadRetryTriggerController()
        loadController = factory.makeLoadController(backupController: backupController, tower: tower, cleanedUploadingStore: failedPhotosResource, cleanedPhotosRetryEvent: retryTriggerController.updatePublisher, progressRepository: progressRepository, settingsController: settingsController, identifiersController: identifiersController, skippableCache: dependencies.photoSkippableCache, queueRepository: identifiersQueueRepository, computationalAvailabilityController: computationalAvailabilityController, measurementRepository: scanningMeasurementRepository)
        backupProgressController = factory.makeBackupProgressController(tower: tower, libraryProgressController: libraryProgressController, loadController: loadController, photosMoc: photosMOC)
        let backupUploadAvailableController = factory.makePhotosBackupUploadAvailableController(backupController: backupController, networkConstraintController: networkConstraintController, quotaConstraintController: quotaConstraintController)
        let photosManagedObjectContext = tower.storage.newBackgroundContext()
        uploadingPhotosRepository = factory.makeUploadingPhotosRepository(tower: tower, moc: photosManagedObjectContext)
        uploader = factory.makePhotoUploader(tower: tower, keymaker: dependencies.keymaker, cleanedUploadingStore: failedPhotosResource, moc: photosManagedObjectContext, telemetryContainer: telemetryStorageContainer, photoSkippableCache: dependencies.photoSkippableCache, uploadMeasurementRepository: uploadMeasurementRepository, uploadDoneNotifier: uploadDoneNotifier)
        tower.photoUploader = uploader
        uploaderFeeder = factory.makePhotoUploaderFeeder(uploadingPhotosRepository: uploadingPhotosRepository, isAvailableController: backupUploadAvailableController, uploader: uploader, computationalAvailabilityController: computationalAvailabilityController)
        lockBannerRepository = InMemoryScreenLockingBannerRepository()
        backupStateController = factory.makeBackupStateController(progressController: backupProgressController, failuresController: failuresController, settingsController: settingsController, authorizationController: authorizationController, networkController: networkConstraintController, quotaController: quotaConstraintController, availableSpaceController: availableSpaceController, featureFlagController: featureFlagController, retryTriggerController: retryTriggerController, computationalAvailabilityController: computationalAvailabilityController, loadController: loadController)
        self.photoLeftoversCleaner = factory.makeCleanupController(tower: tower, photosMoc: photosMOC)
        let processingPipelineWorker = UploadWorkerStateComposite(primaryWorker: backupStateController, secondaryWorker: identifiersController)
        let photoUploaderWorker = LocalDatabasePhotosUploadingWorkerState(storageManager: dependencies.tower.storage)
        let globalWorker = UploadWorkerStateComposite(primaryWorker: processingPipelineWorker, secondaryWorker: photoUploaderWorker)

        // Photos enabled policy, contains feature flags protections
        let lockPolicy = TimeoutLockProtectionEnabledPolicy(settingsProvider: DriveKeychain.shared, protectionResource: dependencies.keymaker)
        let photosEnabledPolicy = PhotosTaskSchedulerEnabledPolicy(lockPolicy: lockPolicy, featureFlagStore: dependencies.tower.localSettings)

        childContainers = [
            PhotosNotificationsPermissionsContainer(tower: tower, windowScene: dependencies.windowScene, backupAvailableController: backupUploadAvailableController),
            telemetryStorageContainer,
            PhotosTelemetryContainer(dependencies: PhotosTelemetryContainer.Dependencies(tower: tower, settingsSuite: dependencies.settingsSuite, settingsController: settingsController, stateController: backupStateController, storage: telemetryStorageContainer.storage, loadController: loadController, uploadRepository: uploadMeasurementRepository, scanningRepository: scanningMeasurementRepository, duplicatesRepository: duplicatesMeasurementRepository, throttlingRepository: throttlingMeasurementRepository, computationalAvailabilityController: computationalAvailabilityController, uploadDoneNotifier: uploadDoneNotifier, processingTaskController: processingTaskController)),
            BackgroundPhotoUploadContainer(dependencies: .init(workerState: globalWorker, appBackgroundStateListener: appStateResource.state, computationAvailability: computationalAvailabilityController, backgroundTaskStateController: processingTaskController, externalFeatureFlagStore: tower.localSettings, settingsProvider: DriveKeychain.shared, keymaker: dependencies.keymaker)),
            factory.makeOpenAppReminderChildContainer(tower: tower, photosEnabledPolicy: photosEnabledPolicy, globalWorker: globalWorker, appStateResource: appStateResource),
        ]
        processingContainer = PhotosProcessingContainer(dependencies: PhotosProcessingContainer.Dependencies(tower: tower, backupController: backupController, constraintsController: constraintsController, identifiersController: identifiersController, progressRepository: progressRepository, failedItemsResource: failedPhotosResource, photoSkippableCache: dependencies.photoSkippableCache, settingsController: settingsController, computationalAvailabilityController: computationalAvailabilityController, circuitBreaker: circuitBreakerController, scanningMeasurementRepository: scanningMeasurementRepository, duplicatesMeasurementRepository: duplicatesMeasurementRepository))
        #if HAS_QA_FEATURES
        memoryLogResource = PhotosMemoryHeartbeatLogResource(resource: DeviceMemoryDiagnosticsResource(), storageManager: tower.storage)
        #endif
    }

    private func makeSettingsContainer() -> PhotosSettingsContainer {
        let dependencies = PhotosSettingsContainer.Dependencies(
            settingsController: settingsController,
            authorizationController: authorizationController,
            bootstrapController: bootstrapController,
            tower: dependencies.tower
        )
        return PhotosSettingsContainer(dependencies: dependencies)
    }

    // MARK: Views

    func makeRootViewController() -> UIViewController {
        let dependencies = PhotosScenesContainer.Dependencies(
            tower: dependencies.tower,
            keymaker: dependencies.keymaker,
            networkService: dependencies.networkService,
            backupController: backupController,
            settingsController: settingsController,
            authorizationController: authorizationController,
            bootstrapController: bootstrapController,
            networkConstraintController: networkConstraintController,
            backupProgressController: backupProgressController,
            processingController: processingContainer.processingController,
            uploader: uploader,
            quotaStateController: quotaStateController,
            quotaConstraintController: quotaConstraintController,
            availableSpaceController: availableSpaceController,
            featureFlagController: featureFlagController,
            repository: lockBannerRepository,
            failedPhotosResource: failedPhotosResource,
            backupStateController: backupStateController,
            retryTriggerController: retryTriggerController,
            constraintsController: constraintsController
        )
        let container = PhotosScenesContainer(dependencies: dependencies)
        return container.makeRootViewController()
    }
}

class OpenAppReminderContainer {
    let controller: ScheduleBackgroundTaskController
    let processor: TaskProcessor

    init(controller: ScheduleBackgroundTaskController, processor: TaskProcessor) {
        self.controller = controller
        self.processor = processor
    }
}
