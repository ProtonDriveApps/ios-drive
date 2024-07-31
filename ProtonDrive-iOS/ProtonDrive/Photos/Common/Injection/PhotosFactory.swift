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
import Foundation
import BackgroundTasks
import CoreData
import ProtonCoreKeymaker

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

    func makeBackupController(settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, bootstrapController: PhotosBootstrapController, lockController: PhotoBackupConstraintController) -> PhotosBackupController {
        return DrivePhotosBackupController(authorizationController: authorizationController, settingsController: settingsController, bootstrapController: bootstrapController, lockController: lockController)
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
    func makeLoadController(backupController: PhotosBackupController, tower: Tower, cleanedUploadingStore: DeletedPhotosIdentifierStoreResource, cleanedPhotosRetryEvent: AnyPublisher<Void, Never>, progressRepository: PhotoLibraryLoadProgressRepository, settingsController: PhotoBackupSettingsController, identifiersController: PhotoLibraryIdentifiersController, skippableCache: PhotosSkippableCache, queueRepository: PhotoLibraryIdentifiersQueueRepository, computationalAvailabilityController: ComputationalAvailabilityController, measurementRepository: DurationMeasurementRepository) -> PhotoLibraryLoadController {
        let mappingResource = LocalPhotoLibraryMappingResource()
        let optionsFactory = PHFetchOptionsFactory(supportedMediaTypes: settingsController.supportedMediaTypes, notOlderThan: settingsController.notOlderThan)
        let identifiersRepository = ConcretePhotoLibraryIdentifiersRepository(mappingResource: mappingResource, optionsFactory: optionsFactory, skippableCache: skippableCache)
        let interactor = LocalPhotoLibraryLoadInteractor(resources: [
            LocalPhotoLibraryFetchResource(identifiersRepository: identifiersRepository, measurementRepository: measurementRepository),
            LocalPhotoLibraryUpdateResource(mappingResource: mappingResource, optionsFactory: optionsFactory, queueRepository: queueRepository, measurementRepository: measurementRepository),
            CleanedPhotoLibraryFetchResource(cleanedUploadingStore: cleanedUploadingStore, cleanedPhotosRetryEvent: cleanedPhotosRetryEvent, identifiersRepository: identifiersRepository, measurementRepository: measurementRepository)
        ])
        return LocalPhotoLibraryLoadController(backupController: backupController, identifiersController: identifiersController, computationalAvailabilityController: computationalAvailabilityController, interactor: interactor)
    }

    func makeNetworkConstraintController(backupController: PhotosBackupController, settingsController: PhotoBackupSettingsController) -> PhotoBackupNetworkControllerProtocol {
        let networkInteractor = ConnectedNetworkStateInteractor(resource: makeNetworkStateResource())
        return PhotoBackupNetworkController(backupController: backupController, settingsController: settingsController, interactor: networkInteractor)
    }

    private func makeNetworkStateResource() -> NetworkStateResource {
        #if DEBUG
        if DebugConstants.commandLineContains(flags: [.uiTests, .mockCellularConnection]) {
            return NetworkStateResourceMock(mockedState: .reachable(.cellular))
        } else if DebugConstants.commandLineContains(flags: [.uiTests, .mockNoConnection]) {
            return NetworkStateResourceMock(mockedState: .unreachable)
        }
        #endif
        return MonitoringNetworkStateResource()
    }

    func makePhotosBackupUploadAvailableController(backupController: PhotosBackupController, networkConstraintController: PhotoBackupConstraintController, quotaConstraintController: PhotoBackupConstraintController) -> PhotosBackupUploadAvailableController {
        LocalPhotosBackupUploadAvailableController(backupController: backupController, networkConstraintController: networkConstraintController, quotaConstraintController: quotaConstraintController)
    }

    // swiftlint:disable:next function_parameter_count
    func makeConstraintsController(tower: Tower, backupController: PhotosBackupController, settingsController: PhotoBackupSettingsController, networkConstraintController: PhotoBackupConstraintController, quotaConstraintController: PhotoBackupConstraintController, availableSpaceController: PhotosAvailableSpaceController, circuitBreakerController: ConstraintController, throttlingMeasurementRepository: DurationMeasurementRepository) -> PhotoBackupConstraintsController {
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToUploadingPhotos(moc: tower.storage.newBackgroundContext()))
        let resource = UploadingPhotoAssetsStorageSizeResource(observer: observer)
        let interactor = LocalPhotoAssetsStorageConstraintInteractor(resource: resource)
        let storageController = PhotoAssetsStorageController(backupController: backupController, interactor: interactor)
        let thermalController = ThermalConstraintController(resource: ProcessThermalStateResource(), measurementRepository: throttlingMeasurementRepository)
        let featureFlagController = makeFeatureFlagController(tower: tower)
        return LocalPhotoBackupConstraintsController(storageController: storageController, networkController: networkConstraintController, quotaController: quotaConstraintController, thermalController: thermalController, availableSpaceController: availableSpaceController, featureFlagController: featureFlagController, circuitBreakerController: circuitBreakerController)
    }

    func makeFeatureFlagController(tower: Tower) -> PhotoBackupConstraintController {
        FeatureFlagConstraintController(resource: tower.localSettings, keyPath: \.photosUploadDisabled)
    }

    func makeUploadingPhotosRepository(tower: Tower, moc: NSManagedObjectContext) -> UploadingPrimaryPhotosRepository {
        StorageUploadingPhotosRepository(storage: tower.storage, moc: moc)
    }

    func makePhotoUploaderFeeder(uploadingPhotosRepository: UploadingPrimaryPhotosRepository, isAvailableController: PhotosBackupUploadAvailableController, uploader: PhotoUploader, computationalAvailabilityController: ComputationalAvailabilityController) -> PhotoUploaderFeeder {
        let shouldFeedPublisher = ComputationalAvailabilityControllerFeederEnabledAdapter(computationalAvailabilityController).isFeederEnabled
        return PhotoUploaderFeeder(
            uploader: uploader,
            uploadingPhotosRepository: uploadingPhotosRepository,
            notificationCenter: NotificationCenter.default,
            isBackupAvailable: isAvailableController.isAvailable,
            newPhotoAvailable: NotificationCenter.default.getPublisher(for: .didImportPhotos, publishing: [PDCore.Photo].self),
            shouldFeedPublisher: shouldFeedPublisher
        )
    }

    // swiftlint:disable:next function_parameter_count
    func makePhotoUploader(tower: Tower, keymaker: Keymaker, cleanedUploadingStore: DeletedPhotosIdentifierStoreResource, moc: NSManagedObjectContext, telemetryContainer: PhotosTelemetryStorageContainer, photoSkippableCache: PhotosSkippableCache, durationMeasurementRepository: DurationMeasurementRepository, uploadDoneNotifier: PhotoUploadDoneNotifier, filesMeasurementRepository: FileUploadFilesMeasurementRepositoryProtocol, blocksMeasurementRepository: FileUploadBlocksMeasurementRepositoryProtocol) -> PhotoUploader {
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
            pagesQueue: pagesQueue,
            uploadQueue: uploadQueue,
            encryptionQueue: encryptionQueue,
            verifierFactory: tower.uploadVerifierFactory,
            finishResource: telemetryContainer.makeUploadFinishResource(),
            blocksMeasurementRepository: blocksMeasurementRepository
        )
        let measurementRepositoryFactory = ConcretePhotoUploadMeasurementRepositoryFactory(notifier: uploadDoneNotifier)
        return PhotoUploader(concurrentOperations: Constants.photosUploaderParallelProcessingCount, fileUploadFactory: photoUploadFactory.make(), featureFlags: tower.featureFlags, deletedPhotosIdentifierStore: cleanedUploadingStore, filecleaner: tower.cloudSlot, moc: moc, skippableCache: photoSkippableCache, dispatchQueue: makeDispatchQueue(), childQueues: [pagesQueue, uploadQueue, encryptionQueue], durationMeasurementRepository: durationMeasurementRepository, filesMeasurementRepository: filesMeasurementRepository, measurementRepositoryFactory: measurementRepositoryFactory, protectionResource: keymaker)
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

    func makeBackupProgressController(tower: Tower, libraryProgressController: PhotosLoadProgressController, loadController: PhotoLibraryLoadController, photosMoc: NSManagedObjectContext) -> PhotosBackupProgressController {
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPrimaryUploadingPhotos(moc: photosMoc))
        let uploadsRepository = DatabasePhotoUploadsRepository(observer: observer)
        let uploadsController = LocalPhotosUploadsProgressController(repository: uploadsRepository)
        return LocalPhotosBackupProgressController(libraryLoadController: libraryProgressController, uploadsController: uploadsController, loadController: loadController, debounceResource: CommonLoopDebounceResource())
    }

    func makeQuotaStateController(tower: Tower) -> QuotaStateController {
        let quotaResource = MainQueueQuotaResource(backgroundResource: tower.sessionVault)
        return UserQuotaStateController(resource: quotaResource)
    }

    func makeQuotaConstraintController(quotaStateController: QuotaStateController) -> PhotoBackupConstraintController {
        QuotaConstraintController(quotaController: quotaStateController)
    }

    func makeLockConstraintController(tower: Tower, keymaker: Keymaker) -> PhotoBackupConstraintController {
        let removedMainKeyPublisher = NotificationCenter.default.publisher(for: Keymaker.Const.removedMainKeyFromMemory)
            .merge(with: NotificationCenter.default.publisher(for: Keymaker.Const.requestMainKey))
            .filter { _ in keymaker.isProtected() == true }
            .map { _ in Void() }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()

        let obtainedMainKeyPublisher = NotificationCenter.default.publisher(for: Keymaker.Const.obtainedMainKey)
            .map { _ in Void() }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()

        return LockConstraintController(isLockedResource: keymaker.isLocked, removedMainKeyResource: removedMainKeyPublisher, obtainedMainKeyResource: obtainedMainKeyPublisher)
    }

    func makeAvailableSpaceController(tower: Tower, backupController: PhotosBackupController, computationalAvailabilityController: ComputationalAvailabilityController) -> PhotosAvailableSpaceController {
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToUploadingPhotos(moc: tower.storage.newBackgroundContext()))
        let resource = ConcretePhotosAvailableSpaceResource(observer: observer)
        let interactor = ConcretePhotosAvailableSpaceInteractor(resource: resource)
        return PhotosAvailableSpaceController(backupController: backupController, computationalAvailabilityController: computationalAvailabilityController, interactor: interactor)
    }

    func makeDispatchQueue() -> DispatchQueue {
        DispatchQueue(label: "PhotoBackupQueue", qos: .utility, attributes: .concurrent)
    }

    // swiftlint:disable:next function_parameter_count
    func makeBackupStateController(progressController: PhotosBackupProgressController, failuresController: PhotosBackupFailuresController, settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, networkController: PhotoBackupNetworkControllerProtocol, quotaController: PhotoBackupConstraintController, availableSpaceController: PhotoBackupConstraintController, featureFlagController: PhotoBackupConstraintController, retryTriggerController: PhotoLibraryLoadRetryTriggerController, computationalAvailabilityController: ComputationalAvailabilityController, loadController: PhotoLibraryLoadController) -> LocalPhotosBackupStateController {
        let completeController = LocalPhotosBackupCompleteController(progressController: progressController, failuresController: failuresController, retryTriggerController: retryTriggerController, timerFactory: MainQueueTimerFactory())
        let applicationStateController = ApplicationStateBackupConstraintController(availabilityController: computationalAvailabilityController)
        return LocalPhotosBackupStateController(progressController: progressController, failuresController: failuresController, completeController: completeController, settingsController: settingsController, authorizationController: authorizationController, networkController: networkController, quotaController: quotaController, availableSpaceController: availableSpaceController, featureFlagController: featureFlagController, applicationStateController: applicationStateController, loadController: loadController, strategy: PrioritizedPhotosBackupStateStrategy(), throttleResource: MainQueueThrottleResource())
    }

    func makeComputationalAvailabilityController(extensionTaskController: BackgroundTaskStateController, processingTaskController: BackgroundTaskStateController) -> ComputationalAvailabilityController {
        let stateController = ConcreteApplicationStateController(stateResource: ApplicationRunningStateResourceImpl())
        return ConcreteComputationalAvailabilityController(processId: "photos", extensionController: extensionTaskController, processingController: processingTaskController, applicationStateController: stateController)
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
}

// Adapter
extension OpenAppReminderTaskSchedulerPolicy: BackgroundWorkPolicy {
    var canExecute: Bool {
        canSchedule
    }
}
