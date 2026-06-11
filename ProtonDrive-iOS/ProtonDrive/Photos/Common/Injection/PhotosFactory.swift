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
import PDCoreIOS
import PDClient
import Combine
import Foundation
import BackgroundTasks
import CoreData
import ProtonCoreKeymaker
import PDPhotos
import ProtonCoreFeatureFlags

struct PhotosFactory {
    func makeSettingsController(localSettings: LocalSettings) -> PhotoBackupSettingsController {
        LocalPhotoBackupSettingsController(localSettings: localSettings)
    }

    func makeAuthorizationController() -> PhotoLibraryAuthorizationController {
        LocalPhotoLibraryAuthorizationController(resource: LocalPhotoLibraryAuthorizationResource())
    }

    func makePhotosBootstrapController(
        tower: Tower,
        telemetryContainer: PhotosTelemetryStorageContainer,
        photoSharesObserver: FetchedResultsControllerObserver<PDCore.Share>
    ) -> PhotosBootstrapController {
        let local = makeLocalPhotosRootDataSource(observer: photoSharesObserver)
        let remoteFetching = RemoteFetchingPhotosRootDataSource(storage: tower.storage, photoShareListing: tower.client)
        let finishResource = telemetryContainer.makeShareCreationFinishResource()
        let remoteCreating = RemoteCreatingPhotosRootDataSource(storage: tower.storage, sessionVault: tower.sessionVault, photoShareCreator: tower.client, finishResource: finishResource)

        let interactor = PhotoShareBootstrapInteractor(
            dataSource: FallbackPhotosShareDataSource(
                primary: local,
                secondary: FallbackPhotosShareDataSource(
                    primary: remoteFetching,
                    secondary: remoteCreating
                )
            )
        )
        let repository = FetchResultControllerObserverPhotosBootstrapRepository(observer: photoSharesObserver)
        return MonitoringBootstrapController(interactor: interactor, repository: repository)
    }

    /// Don't use this function directly, use `PhotosContainer.photoSharesObserver`
    func makePhotoSharesObserver(tower: Tower) -> FetchedResultsControllerObserver<PDCore.Share> {
        FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPhotoShares(moc: tower.storage.backgroundContext))
    }

    func makeLocalPhotosRootDataSource(observer: FetchedResultsControllerObserver<PDCore.Share>) -> PhotosShareDataSource {
        LocalPhotosRootDataSource(observer: observer)
    }

    // swiftlint:disable:next function_parameter_count
    func makeBackupController(
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        bootstrapController: PhotosBootstrapController,
        lockController: PhotoBackupConstraintController,
        b2bUserConstraintController: PhotoBackupConstraintController,
        populatedStateController: PopulatedStateControllerProtocol
    ) -> PhotosBackupController {
        return DrivePhotosBackupController(
            authorizationController: authorizationController,
            settingsController: settingsController,
            bootstrapController: bootstrapController,
            lockController: lockController,
            b2BUserController: b2bUserConstraintController,
            populatedStateController: populatedStateController
        )
    }

    func makeCleanupController(tower: Tower, photosMoc: NSManagedObjectContext) -> PhotoLeftoversCleaner {
        let fileSystemCleaner = FileSystemCleanPhotoLeftoverCommand(fileManager: FileManager.default, photosDirectory: PDFileManager.cleartextPhotosCacheDirectory)
        let coredataCleaner = CoredataCleanPhotoLeftoversCommand(storage: tower.storage, moc: photosMoc)
        let cleanerCommand = CommandComposite(commands: [fileSystemCleaner, coredataCleaner])
        return PhotoLeftoversCleaner(
            isEnabledPublisher: tower.localSettings.publisher(for: \.isPhotosBackupEnabled).eraseToAnyPublisher(),
            scheduler: DispatchQueue.global().eraseToAnyScheduler(),
            cleanPhotoLeftOvers: cleanerCommand
        )
    }

    // swiftlint:disable:next function_parameter_count
    func makeLoadController(
        backupController: PhotosBackupController,
        tower: Tower,
        cleanedUploadingStore: DeletedPhotosIdentifierStoreResource,
        cleanedPhotosRetryEvent: AnyPublisher<Void, Never>,
        progressRepository: PhotoLibraryLoadProgressRepository,
        settingsController: PhotoBackupSettingsController,
        identifiersController: PhotoLibraryIdentifiersController,
        skippableCache: PhotosSkippableCache,
        queueRepository: PhotoLibraryIdentifiersQueueRepository,
        computationalAvailabilityController: ComputationalAvailabilityController,
        measurementRepository: DurationMeasurementRepository,
        photoIdentifierStore: PhotoIdentifierStore
    ) -> PhotoLibraryLoadController {
        let mappingResource = LocalPhotoLibraryMappingResource()
        let optionsFactory = PHFetchOptionsFactory(supportedMediaTypes: settingsController.supportedMediaTypes, notOlderThan: settingsController.notOlderThan)
        let identifiersRepository = ConcretePhotoLibraryIdentifiersRepository(
            mappingResource: mappingResource,
            optionsFactory: optionsFactory,
            skippableCache: skippableCache,
            identifierStore: photoIdentifierStore
        )
        let interactor = LocalPhotoLibraryLoadInteractor(resources: [
            LocalPhotoLibraryFetchResource(identifiersRepository: identifiersRepository, measurementRepository: measurementRepository),
            LocalPhotoLibraryUpdateResource(
                mappingResource: mappingResource,
                optionsFactory: optionsFactory,
                queueRepository: queueRepository,
                measurementRepository: measurementRepository,
                identifierStore: photoIdentifierStore
            ),
            CleanedPhotoLibraryFetchResource(cleanedUploadingStore: cleanedUploadingStore, cleanedPhotosRetryEvent: cleanedPhotosRetryEvent, identifiersRepository: identifiersRepository, measurementRepository: measurementRepository)
        ])
        let scheduler = DispatchQueue.main.eraseToAnyScheduler()
        return LocalPhotoLibraryLoadController(backupController: backupController, identifiersController: identifiersController, computationalAvailabilityController: computationalAvailabilityController, interactor: interactor, scheduler: scheduler)
    }

    func makeNetworkConstraintController(settingsController: PhotoBackupSettingsController, connectionStateResource: ConnectionStateResource) -> PhotoBackupNetworkControllerProtocol {
        let resource = makeNetworkStateResource(connectionStateResource: connectionStateResource)
        return PhotoBackupNetworkController(settingsController: settingsController, interactor: resource)
    }

    private func makeNetworkStateResource(connectionStateResource: ConnectionStateResource) -> ConnectionStateResource {
        #if DEBUG
        if DebugConstants.commandLineContains(flags: [.uiTests, .mockCellularConnection]) {
            return ConnectionStateResourceSpy(state: .reachable(.cellular))
        } else if DebugConstants.commandLineContains(flags: [.uiTests, .mockNoConnection]) {
            return ConnectionStateResourceSpy(state: .unreachable)
        }
        #endif
        return connectionStateResource
    }

    func makePhotosBackupUploadAvailableController(backupController: PhotosBackupController, networkConstraintController: PhotoBackupConstraintController, quotaConstraintController: PhotoBackupConstraintController, migrationConstraintController: PhotoBackupConstraintController) -> PhotosBackupUploadAvailableController {
        LocalPhotosBackupUploadAvailableController(backupController: backupController, networkConstraintController: networkConstraintController, quotaConstraintController: quotaConstraintController, migrationConstraintController: migrationConstraintController)
    }

    // swiftlint:disable:next function_parameter_count
    func makeConstraintsController(
        tower: Tower,
        backupController: PhotosBackupController,
        settingsController: PhotoBackupSettingsController,
        networkConstraintController: PhotoBackupConstraintController,
        quotaConstraintController: PhotoBackupConstraintController,
        availableSpaceController: PhotosAvailableSpaceController,
        circuitBreakerController: ConstraintController,
        throttlingMeasurementRepository: DurationMeasurementRepository,
        migrationConstraintController: PhotoBackupConstraintController,
        featureFlagController: PhotoBackupConstraintController
    ) -> PhotoBackupConstraintsController {
        let observer = FetchedResultsControllerObserver(
            controller: tower.storage.subscriptionToUploadingPhotos(moc: tower.storage.photosSecondaryBackgroundContext),
            isAutomaticallyStarted: false
        )
        let resource = UploadingPhotoAssetsStorageSizeResource(observer: observer)
        let interactor = LocalPhotoAssetsStorageConstraintInteractor(resource: resource)
        let storageController = PhotoAssetsStorageController(backupController: backupController, interactor: interactor)
        let thermalController = ThermalConstraintController(resource: ProcessThermalStateResource(), measurementRepository: throttlingMeasurementRepository)
        return LocalPhotoBackupConstraintsController(storageController: storageController, networkController: networkConstraintController, quotaController: quotaConstraintController, thermalController: thermalController, availableSpaceController: availableSpaceController, featureFlagController: featureFlagController, circuitBreakerController: circuitBreakerController, migrationController: migrationConstraintController)
    }

    func makeFeatureFlagController(tower: Tower) -> PhotoBackupConstraintController {
        FeatureFlagConstraintController(resource: tower.localSettings, keyPath: \.photosUploadDisabled)
    }

    func makeUploadingPhotosRepository(tower: Tower, moc: NSManagedObjectContext) -> UploadingPrimaryPhotosRepository {
        StorageUploadingPhotosRepository(storage: tower.storage, moc: moc)
    }

    // swiftlint:disable:next function_parameter_count
    func makePhotoUploaderFeeder(
        tower: Tower,
        isAvailableController: PhotosBackupUploadAvailableController,
        uploader: PhotoUploader,
        computationalAvailabilityController: ComputationalAvailabilityController,
        feedProcessor: PhotoFeederPreprocessorProtocol,
        feedSubject: PassthroughSubject<Void, Never>
    ) -> PhotoUploaderFeeder {
        let shouldFeedPublisher = ComputationalAvailabilityControllerFeederEnabledAdapter(computationalAvailabilityController).isFeederEnabled
        return PhotoUploaderFeeder(
            uploader: uploader,
            sdkPhotoUploaderBlock: { [weak tower] in
                tower?.getSdkPhotoUploader()
            },
            notificationCenter: NotificationCenter.default,
            isBackupAvailable: isAvailableController.isAvailable,
            shouldFeedPublisher: shouldFeedPublisher,
            processor: feedProcessor,
            feedSubject: feedSubject
        )
    }

    // swiftlint:disable:next function_parameter_count
    func makePhotoFeederProcessor(
        tower: Tower,
        failedIdentifiersResource: DeletedPhotosIdentifierStoreResource,
        featureFlagsController: FeatureFlagsControllerProtocol,
        feedPublisher: AnyPublisher<Void, Never>,
        moc: NSManagedObjectContext,
        photoIdentifierInquirer: PhotoIdentifierInquirer,
        retryTriggerController: PhotoLibraryLoadRetryTriggerController,
        settingsController: PhotoBackupSettingsController,
        uploader: PhotoUploader,
        uploadingPhotosRepository: UploadingPrimaryPhotosRepository
    ) -> PhotoFeederPreprocessor {
        let factory = PHFetchOptionsFactory(
            supportedMediaTypes: settingsController.supportedMediaTypes,
            notOlderThan: settingsController.notOlderThan
        )
        let sizeResource = PhotoCacheFolderSizeResource(storageSizeLimit: Constants.photosAssetsMaximalFolderSize)
        return PhotoFeederPreprocessor(
            dependencies: .init(
                allowedBatchSize: PDCore.Constants.processingPhotoUploadsBatchSize,
                failedIdentifiersResource: failedIdentifiersResource,
                featureFlagsController: featureFlagsController,
                feedPublisher: feedPublisher,
                folderSizeResource: sizeResource,
                optionsFactory: factory,
                photoIdentifierInquirer: photoIdentifierInquirer,
                retryTriggerController: retryTriggerController,
                storageManager: tower.storage,
                uploader: uploader,
                sdkPhotoUploader: tower.getSdkPhotoUploader(),
                uploadingPhotosRepository: uploadingPhotosRepository
            )
        )
    }

    // swiftlint:disable:next function_parameter_count
    func makePhotoUploader(
        tower: Tower,
        keymaker: Keymaker,
        cleanedUploadingStore: DeletedPhotosIdentifierStoreResource,
        moc: NSManagedObjectContext,
        telemetryContainer: PhotosTelemetryStorageContainer,
        photoSkippableCache: PhotosSkippableCache,
        durationMeasurementRepository: DurationMeasurementRepository,
        uploadDoneNotifier: PhotoUploadDoneNotifier,
        filesMeasurementRepository: FileUploadFilesMeasurementRepositoryProtocol,
        blocksMeasurementRepository: FileUploadBlocksMeasurementRepositoryProtocol,
        photoUploadedNotifier: PhotoUploadedNotifier
    ) -> PhotoUploader {
        // There are 3 heavy operations that run in for each Photo: page upload, blocks/thumbnail upload and encryption.
        // By injecting serial queues, even for multiple Photos uploading, only one of each operations will run at a time. Thus keeping CPU usage at a normal level.
        let pagesQueue = makeSerialOperationQueue()
        let uploadQueue = makeSerialOperationQueue()
        let encryptionQueue = makeSerialOperationQueue()
        let photoUploadFactory = PhotosUploadOperationsProviderFactory(
            storage: tower.storage,
            client: tower.client,
            cloudSlot: tower.cloudSlot,
            sessionVault: tower.sessionVault,
            apiService: tower.api,
            moc: moc,
            parallelEncryption: tower.parallelEncryption,
            pagesQueue: pagesQueue,
            uploadQueue: uploadQueue,
            encryptionQueue: encryptionQueue,
            verifierFactory: tower.uploadVerifierFactory,
            finishResource: telemetryContainer.makeUploadFinishResource(),
            blocksMeasurementRepository: blocksMeasurementRepository,
            uploadedBytesCounterResource: tower.uploadedBytesCounterResource
        )
        let measurementRepositoryFactory = ConcretePhotoUploadMeasurementRepositoryFactory(notifier: uploadDoneNotifier)

        return PhotoUploader(
            concurrentOperations: Constants.photosUploaderParallelProcessingCount,
            fileUploadFactory: photoUploadFactory.make(),
            featureFlags: tower.featureFlags,
            deletedPhotosIdentifierStore: cleanedUploadingStore,
            filecleaner: tower.cloudSlot,
            moc: moc,
            skippableCache: photoSkippableCache,
            dispatchQueue: makeDispatchQueue(),
            childQueues: [pagesQueue, uploadQueue, encryptionQueue],
            durationMeasurementRepository: durationMeasurementRepository,
            filesMeasurementRepository: filesMeasurementRepository,
            measurementRepositoryFactory: measurementRepositoryFactory,
            protectionResource: keymaker,
            photoUploadedNotifier: photoUploadedNotifier
        )
    }

    private func makeSerialOperationQueue() -> OperationQueue {
        OperationQueue(maxConcurrentOperation: 1, underlyingQueue: .global())
    }

    func makeBackupProgressRepository() -> PhotoLibraryLoadProgressActionRepository & PhotoLibraryLoadProgressRepository {
        LocalPhotoLibraryLoadProgressActionRepository()
    }

    func makeLibraryProgressController(repository: PhotoLibraryLoadProgressActionRepository) -> PhotosLoadProgressController & PhotoLibraryLoadProgressController {
        LocalPhotoLibraryLoadProgressController(interactor: repository)
    }

    func makeBackupProgressController(
        tower: Tower,
        libraryProgressController: PhotosLoadProgressController,
        loadController: PhotoLibraryLoadController,
        photosMoc: NSManagedObjectContext,
        isAvailableController: PhotosBackupUploadAvailableController
    ) -> PhotosBackupProgressController {
        let uploadsRepository = DatabasePhotoUploadsRepository(
            isBackupAvailable: isAvailableController,
            photosMoc: photosMoc,
            storage: tower.storage
        )
        let uploadsController = LocalPhotosUploadsProgressController(repository: uploadsRepository)
        return LocalPhotosBackupProgressController(libraryLoadController: libraryProgressController, uploadsController: uploadsController, loadController: loadController, debounceResource: CommonLoopDebounceResource())
    }

    func makeQuotaStateController(tower: Tower) -> QuotaStateController {
        let quotaResource = MainQueueQuotaResource(backgroundResource: tower.sessionVault)
        return UserQuotaStateController(resource: quotaResource, setting: tower.localSettings)
    }

    func makeQuotaConstraintController(quotaStateController: QuotaStateController) -> PhotoBackupConstraintController {
        QuotaConstraintController(quotaController: quotaStateController)
    }

    func makeLockConstraintController(lockedStateController: LockedStateControllerProtocol) -> PhotoBackupConstraintController {
        return LockConstraintController(lockedStateController: lockedStateController)
    }

    func makeB2BUserConstraintController(tower: Tower, featureFlagsController: FeatureFlagsControllerProtocol) -> PhotoBackupConstraintController {
        return B2BPhotosUploadConstraintController(localSettings: tower.localSettings, repository: ProtonCoreFeatureFlags.FeatureFlagsRepository.shared)
    }

    func makeAvailableSpaceController(tower: Tower, backupController: PhotosBackupController, computationalAvailabilityController: ComputationalAvailabilityController) -> PhotosAvailableSpaceController {
        let observer = FetchedResultsControllerObserver(
            controller: tower.storage.subscriptionToUploadingPhotos(moc: tower.storage.photosSecondaryBackgroundContext),
            isAutomaticallyStarted: false
        )
        let resource = ConcretePhotosAvailableSpaceResource(observer: observer)
        let interactor = ConcretePhotosAvailableSpaceInteractor(resource: resource)
        return PhotosAvailableSpaceController(backupController: backupController, computationalAvailabilityController: computationalAvailabilityController, interactor: interactor)
    }

    func makeDispatchQueue() -> DispatchQueue {
        DispatchQueue(label: "PhotoBackupQueue", qos: .utility, attributes: .concurrent)
    }

    // swiftlint:disable:next function_parameter_count
    func makeBackupStateController(progressController: PhotosBackupProgressController, failuresController: PhotosBackupFailuresController, settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, networkController: PhotoBackupNetworkControllerProtocol, quotaController: PhotoBackupConstraintController, availableSpaceController: PhotoBackupConstraintController, featureFlagController: PhotoBackupConstraintController, retryTriggerController: PhotoLibraryLoadRetryTriggerController, computationalAvailabilityController: ComputationalAvailabilityController, loadController: PhotoLibraryLoadController, migrationConstraintController: PhotoBackupConstraintController) -> LocalPhotosBackupStateController {
        let completeController = LocalPhotosBackupCompleteController(progressController: progressController, failuresController: failuresController, loadController: loadController, retryTriggerController: retryTriggerController, timerFactory: MainQueueTimerFactory())
        let applicationStateController = ApplicationStateBackupConstraintController(availabilityController: computationalAvailabilityController)
        return LocalPhotosBackupStateController(progressController: progressController, failuresController: failuresController, completeController: completeController, settingsController: settingsController, authorizationController: authorizationController, networkController: networkController, quotaController: quotaController, availableSpaceController: availableSpaceController, featureFlagController: featureFlagController, applicationStateController: applicationStateController, loadController: loadController, migrationController: migrationConstraintController, strategy: PrioritizedPhotosBackupStateStrategy(), throttleResource: MainQueueThrottleResource())
    }

    func makeComputationalAvailabilityController(
        extensionTaskController: BackgroundTaskStateController,
        processingTaskController: BackgroundTaskStateController,
        lockedStateController: LockedStateControllerProtocol
    ) -> ComputationalAvailabilityController {
        let stateController = ConcreteApplicationStateController(stateResource: iOSApplicationRunningStateResource())
        return ConcreteComputationalAvailabilityController(
            processId: "photos",
            extensionController: extensionTaskController,
            processingController: processingTaskController,
            applicationStateController: stateController,
            lockedStateController: lockedStateController
        )
    }

    func makeOpenAppReminderChildContainer(tower: Tower, globalWorker: WorkerState, appStateResource: ApplicationRunningStateResource) -> OpenAppReminderContainer {
        let photosEnabledPolicy = OpenAppReminderTaskSchedulerPolicy(localSettings: tower.localSettings)
        let coredataLastPhotoRepository = LocalCoredataLastPhotoRepository(moc: tower.storage.photosBackgroundContext, storage: tower.storage)
        let openAppReminderScheduler = BackgroundOpenAppReminderSchedulerFactory().makeTaskScheduler(dependencies: .init(
            enabledPolicy: photosEnabledPolicy))
        let openAppReminderSchedulerController = ScheduleBackgroundTaskController(statePublisher: appStateResource.state, taskScheduler: openAppReminderScheduler)
        let openAppReminderphotoUploadsWorkerState = BackgroundPhotoUploadWorkObserverFactory().makeBackgroundUploadWorkerState(.init(scheduledPhotosUploadWorkerState: globalWorker, coredataLastPhotoRepository: coredataLastPhotoRepository, galleryLastPhotoRepository: GalleryLastPhotoRepository()))
        let openAppReminderTaskProcessor = BackgroundOpenAppReminderTaskProcessorFactory().makeOpenPhotosNotificationTaskProcessor(.init(photoUploadsWorkerState: openAppReminderphotoUploadsWorkerState, backgroundTaskScheduler: openAppReminderScheduler, backgroundWorkPolicy: photosEnabledPolicy))
        return OpenAppReminderContainer(controller: openAppReminderSchedulerController, processor: openAppReminderTaskProcessor)
    }

    func makePagingLoadController(
        tower: Tower,
        bootstrapController: PhotosBootstrapController,
        networkConstraintController: PhotoBackupConstraintController,
        photoSharesObserver: FetchedResultsControllerObserver<PDCore.Share>,
        errorController: ErrorSetControllerProtocol
    ) -> PhotosPagingLoadController {
        let dataSource = makeLocalPhotosRootDataSource(observer: photoSharesObserver)
        let volumeIdDataSource = DatabasePhotosVolumeIdDataSource(photoShareDataSource: dataSource)
        let listInteractor = PhotosListLoadInteractor(volumeIdDataSource: volumeIdDataSource, listing: tower.client)
        let listFacadeInteractor = AsyncPhotosListLoadResultInteractor(interactor: listInteractor)
        let managedObjectContext = tower.storage.photosSecondaryBackgroundContext
        let updateRepository = CoreDataLinksUpdateRepository(cloudSlot: tower.cloudSlot, managedObjectContext: managedObjectContext)
        let metadataInteractor = PhotosMetadataLoadInteractor(shareIdDataSource: DatabasePhotoShareIdDataSource(dataSource: dataSource), listing: tower.client, updateRepository: updateRepository)
        let metadataFacadeInteractor = AsyncPhotosMetadataLoadResultInteractor(interactor: metadataInteractor)
        let interactor = RemotePhotosFullLoadInteractor(listInteractor: listFacadeInteractor, metadataInteractor: metadataFacadeInteractor)
        return RemotePhotosPagingLoadController(bootstrapController: bootstrapController, interactor: interactor, errorController: errorController)
    }

    func makeMigrationConstraintController(errorControllers: [ErrorController]) -> PhotoBackupConstraintController {
        return MigrationToPhotoVolumeConstraintController(errorControllers: errorControllers)
    }
}

// Adapter
extension OpenAppReminderTaskSchedulerPolicy: BackgroundWorkPolicy {
    var canExecute: Bool {
        canSchedule
    }
}
