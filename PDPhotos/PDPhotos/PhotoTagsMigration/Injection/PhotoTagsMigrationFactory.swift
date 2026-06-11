// Copyright (c) 2025 Proton AG
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
import PDClient
import PDCoreIOS

public protocol MigrationCommandFactory {
    func makeMigrationCommand(volumeID: String) -> (Command & WorkingNotifier)
}

public final class PhotoTagsMigrationFactory: MigrationCommandFactory {
    private let localSettings: LocalSettings
    private let client: Client
    private let downloader: Downloader
    private let sdkDownloader: SDKFileDownloaderProtocol?
    private let sessionVault: SessionVault
    private let storageManager: StorageManager
    private let listingDataSource: PhotosListingDataSource
    private let photoUploadedNotifier: PhotoUploadedNotifier
    private let featureFlags: FeatureFlagsControllerProtocol
    private let lockConstraintController: PhotoBackupConstraintController
    private let connectionStateResource: ConnectionStateResource
    private let authorizationController: PhotoLibraryAuthorizationController
    private let rootFolderRepository: PhotosRootFolderRepository
    private let photoIdentifierInquirer: PhotoIdentifierInquirer

    public init(
        localSettings: LocalSettings,
        storageManager: StorageManager,
        featureFlags: FeatureFlagsControllerProtocol,
        client: Client,
        sessionVault: SessionVault,
        downloader: Downloader,
        sdkDownloader: SDKFileDownloaderProtocol?,
        listingDataSource: PhotosListingDataSource,
        photoUploadedNotifier: PhotoUploadedNotifier,
        lockConstraintController: PhotoBackupConstraintController,
        connectionStateResource: ConnectionStateResource,
        authorizationController: PhotoLibraryAuthorizationController,
        rootFolderRepository: PhotosRootFolderRepository,
        photoIdentifierInquirer: PhotoIdentifierInquirer
    ) {
        self.localSettings = localSettings
        self.client = client
        self.downloader = downloader
        self.sdkDownloader = sdkDownloader
        self.sessionVault = sessionVault
        self.storageManager = storageManager
        self.listingDataSource = listingDataSource
        self.photoUploadedNotifier = photoUploadedNotifier
        self.featureFlags = featureFlags
        self.lockConstraintController = lockConstraintController
        self.connectionStateResource = connectionStateResource
        self.authorizationController = authorizationController
        self.rootFolderRepository = rootFolderRepository
        self.photoIdentifierInquirer = photoIdentifierInquirer
    }

    public func makeMigrationCommand(volumeID: String) -> (Command & WorkingNotifier) {
        // Resources
        let contentResource = LocalPhotoLibraryFileContentResource()
        let assetFactory = LocalPhotoAssetFactory(nameStrategy: LocalPhotoLibraryFilenameStrategy())
        let exifResource = CoreImagePhotoLibraryExifResource(parser: CoreImagePhotoLibraryExifParser())
        let assetResource = TagsLocalPhotoLibraryAssetResource(
            contentResource: contentResource,
            assetFactory: assetFactory,
            exifResource: exifResource,
            localSettings: localSettings,
            rootFolderRepository: rootFolderRepository,
            encryptionResource: Encryptor()
        )
        let assetDataFetcher = DefaultPhotoAssetDataFetcherResource(photoIdentifierInquirer: photoIdentifierInquirer)
        let xAttrBackfillAnalyzer = DefaultXAttrBackfillAnalyzer(exifResource: exifResource)

        let fileContentResource = DecryptedPhotoContentResource(
            managedObjectContext: storageManager.photosBackgroundContext,
            downloader: downloader,
            sdkDownloader: sdkDownloader,
            fetchResource: PhotoFetchResource(storage: storageManager),
            photoUploadedNotifier: photoUploadedNotifier,
            performanceMetricsController: nil,
            photoDecryptor: RemoteFileContentDecryptor(validator: EmptyFileURLValidationResource()), // We don't need to verify previewability
            isDetailedErrorNotified: false
        )

        // State loader
        let stateLoader = DefaultTagsMigrationStateLoader(
            tagsMigrationClient: client,
            featureFlags: featureFlags,
            localSettings: localSettings,
            currentClientUID: sessionVault.getUploadClientUID()
        )

        // Pager
        let pager = DefaultPhotoTagMigrationPager(
            listingDataSource: listingDataSource,
            metadataRepository: makeRemoteMetadataFetchRepository(storage: storageManager, client: client),
            volumeID: volumeID
        )

        // Analyzer
        let contextResource = CoreDataTaggingContextResource(context: storageManager.photosBackgroundContext)
        let driveMetadata = DriveMetadataTagRule(managedContext: storageManager.photosBackgroundContext)
        let photosMetadata = PhotosMetadataTagRule(assetResource: assetResource, assetDataFetcher: assetDataFetcher, storageManager: storageManager, xAttrBackfillAnalyzer: xAttrBackfillAnalyzer)
        let fileInspection = FileInspectionTagRule(fileContentResource: fileContentResource, managedContext: storageManager.newBackgroundContext(), xAttrBackfillAnalyzer: xAttrBackfillAnalyzer)
        let analyzer = DefaultPhotoTagAnalyzer(initialTaggingContextResource: contextResource, driveMetaPhotoTagRule: driveMetadata, photosMetaPhotoTagRule: photosMetadata, fileExifPhotoTagRule: fileInspection)

        // Batch assigner
        let batchAssigner = DefaultPhotoTagBatchAssigner(tagClient: client, volumeID: volumeID)
        let batchBackfiller = DefaultPhotoXAttrBatchBackfiller(
            client: client,
            encryptor: Encryptor(),
            managedContext: storageManager.newBackgroundContext(),
            signersKitFactory: sessionVault
        )

        // StateUpdater
        let stateUpdater = DefaultPhotoTagsMigrationStateUpdater(
            tagsMigrationClient: client,
            localSettings: localSettings,
            volumeID: volumeID,
            clientUID: sessionVault.getUploadClientUID()
        )

        let blocksDeleter = DefaultProcessedPhotoBlockDeleter(context: storageManager.photosBackgroundContext)

        // Use case
        let useCase = MigratePhotoTagsUseCase(
            stateLoader: stateLoader,
            pager: pager,
            analyzer: analyzer,
            batchAssigner: batchAssigner,
            batchBackfiller: batchBackfiller,
            stateUpdater: stateUpdater,
            blocksDeleter: blocksDeleter,
            volumeID: volumeID
        )

        return NetworkErrorHandlingCommand(interactor: useCase)
    }

    func makeRemoteMetadataFetchRepository(storage: StorageManager, client: Client) -> RemoteMetadataFetchRepository {
        let cacher = CoreDataMetadataCache(store: storage, context: storage.photosBackgroundContext)
        let repository = RemoteMetadataFetchRepository(cacher: cacher, client: client)
        return repository
    }

    // MARK: - MigrationController

    public func makeTagsMigrationConstraintController() -> MigrationConstraintController {
        DefaultMigrationConstraintController(
            networkController: makeNetworkConstraintController(),
            lockController: makeLockConstraintController(),
            storageController: makeStorageConstraintController(),
            photoLibraryAuthorizationController: authorizationController,
            volumeObserver: makeVolumeObserver(),
            settingsController: LocalPhotoBackupSettingsController(localSettings: localSettings)
        )
    }

    public func makeMigrationController(constraintController: MigrationConstraintController) -> PhotoTagsMigrationController {
        return PhotoTagsMigrationController(factory: self, constraintController: constraintController)
    }

    // MARK: - Constraint Controllers
    public func makeNetworkConstraintController() -> PhotoBackupConstraintController {
        let settingsController = LocalPhotoBackupSettingsController(localSettings: localSettings)
        return PhotoBackupNetworkConstraintController(settingsController: settingsController, interactor: connectionStateResource)
    }

    func makeLockConstraintController() -> PhotoBackupConstraintController {
        return lockConstraintController
    }

    public func makeStorageConstraintController() -> PhotoBackupConstraintController {
        let observer = FetchedResultsControllerObserver(
            controller: storageManager.subscriptionToUploadingPhotos(moc: storageManager.photosBackgroundContext),
            isAutomaticallyStarted: false
        )
        let resource = UploadingPhotoAssetsStorageSizeResource(observer: observer)
        let interactor = LocalPhotoAssetsStorageConstraintInteractor(resource: resource)
        return PhotoAssetsStorageController(interactor: interactor)
    }

    public func makeVolumeObserver() -> VolumeIdObserver {
        PhotosVolumeIdObserver(storageManager: storageManager)
    }

}
