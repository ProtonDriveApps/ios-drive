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
import ProtonCoreKeymaker
import PDSDKCore
import PDSDKCoreiOS
import PDCoreIOS

struct AuthenticatedDependenciesFactory {
    private let keymaker: Keymaker
    private let tower: Tower
    private let uploaderFactory: SDKFileUploaderFactory

    init(keymaker: Keymaker, tower: Tower) {
        self.keymaker = keymaker
        self.tower = tower
        self.uploaderFactory = SDKFileUploaderFactory(
            encoder: JSONEncoder(),
            managedObjectContext: tower.storage.backgroundContext,
            protectionResource: keymaker,
            thumbnailProvider: ThumbnailProviderFactory.defaultSynchronizedThumbnailProvider
        )
    }

    func makeLockedStateController() -> LockedStateControllerProtocol {
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
        return LockedStateController(
            eventsTriggerController: tower,
            refreshableStorageResource: CoreDataRefreshableStorageResource(storageManager: tower.storage),
            isLocked: keymaker.isLocked,
            removedMainKeyPublisher: removedMainKeyPublisher,
            obtainedMainKeyPublisher: obtainedMainKeyPublisher
        )
    }

    @MainActor
    func makeSDKUploader(performer: FileOperationPerformer?) -> SDKFileUploaderProtocol? {
        guard let performer else { return nil }
        return uploaderFactory.makeFileUploader(
            bytesCounterResource: ThreadSafeBytesCounterResource(),
            operationPerformer: performer
        )
    }

    @MainActor
    func makeSDKThumbnailsDownloader(performer: FileOperationPerformer?) -> SDKThumbnailsDownloaderProtocol? {
        guard let performer else { return nil }
        return SDKThumbnailsDownloaderFactory().makeFilesThumbnailDownloader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
    }

    @MainActor
    func makeSDKPhotosThumbnailsDownloader(tower: Tower, performer: PhotosOperationPerformer?) -> SDKThumbnailsDownloaderProtocol? {
        guard let performer else { return nil }
        return SDKThumbnailsDownloaderFactory().makePhotosThumbnailDownloader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
    }

    @MainActor
    func makeSDKDownloader(performer: FileOperationPerformer?) -> SDKFileDownloaderProtocol? {
        guard let performer else { return nil }
        return SDKDownloaderFactory().makeFileDownloader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
    }

    @MainActor
    func makeSDKPhotoDownloader(performer: PhotosOperationPerformer?) -> SDKFileDownloaderProtocol? {
        guard let performer else { return nil }
        return SDKDownloaderFactory().makePhotoDownloader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
    }

    @MainActor
    func makeSDKPhotoUploader(
        performer: PhotosOperationPerformer?,
        photoUploadedNotifier: PhotoUploadedNotifier,
        skippableCache: PhotosSkippableCache,
        failedPhotosResource: DeletedPhotosIdentifierStoreResource
    ) -> SDKFileUploaderProtocol? {
        guard let performer else { return nil }
        return uploaderFactory.makePhotoUploader(
            bytesCounterResource: ThreadSafeBytesCounterResource(),
            operationPerformer: performer,
            photoUploadedNotifier: photoUploadedNotifier,
            skippableCache: skippableCache,
            failedPhotosResource: failedPhotosResource,
            photoMoc: tower.storage.photosSecondaryBackgroundContext
        )
    }

    typealias SDKDownloaders = (file: SDKFileDownloaderProtocol?, photo: SDKFileDownloaderProtocol?)
    // swiftlint:disable:next function_parameter_count
    func makeOfflineSavers(
        populatedController: PopulatedStateControllerProtocol,
        connectionStateResource: ConnectionStateResource,
        sdkDownloaders: SDKDownloaders,
        hasSDKDownloadMain: Bool,
        hasSDKDownloadPhoto: Bool
    ) -> [OfflineSaverProtocol] {
        var offlineSavers: [OfflineSaverProtocol] = []
        var initialMainDownloader = false
        var initialPhotoDownloader = false
        if let fileDownloader = sdkDownloaders.file, hasSDKDownloadMain {
            let saver = makeSDKOfflineSaver(
                tower: tower,
                sdkDownloader: fileDownloader,
                connectionStateResource: connectionStateResource,
                configuration: .onlyMyFiles
            )
            offlineSavers.append(saver)
            initialMainDownloader = true
        }

        if let photoDownloader = sdkDownloaders.photo, hasSDKDownloadPhoto {
            let saver = makeSDKOfflineSaver(
                tower: tower,
                sdkDownloader: photoDownloader,
                connectionStateResource: connectionStateResource,
                configuration: .onlyPhotos
            )
            offlineSavers.append(saver)
            initialPhotoDownloader = true
        }

        var legacyConfiguration: OfflineSaverConfiguration?
        switch (initialMainDownloader, initialPhotoDownloader) {
        case (true, true):
            legacyConfiguration = nil
        case (true, false):
            legacyConfiguration = .onlyMyFiles
        case (false, true):
            legacyConfiguration = .onlyMyFiles
        case (false, false):
            legacyConfiguration = .bothMyFilesAndPhotos
        }

        if let legacyConfiguration {
            let saver = makeLegacyOfflineSaver(
                tower: tower,
                populatedController: populatedController,
                connectionStateResource: connectionStateResource,
                configuration: legacyConfiguration
            )
            offlineSavers.append(saver)
        }
        return offlineSavers
    }

    private func makeLegacyOfflineSaver(
        tower: Tower,
        populatedController: PopulatedStateControllerProtocol,
        connectionStateResource: ConnectionStateResource,
        configuration: OfflineSaverConfiguration
    ) -> OfflineSaverProtocol {
        return LegacyOfflineSaver(
            configuration: configuration,
            storage: tower.storage,
            downloader: tower.downloader,
            populatedStateController: populatedController,
            connectionStateResource: connectionStateResource
        )
    }

    private func makeSDKOfflineSaver(
        tower: Tower,
        sdkDownloader: SDKFileDownloaderProtocol,
        connectionStateResource: ConnectionStateResource,
        configuration: OfflineSaverConfiguration
    ) -> OfflineSaverProtocol {
        return SDKOfflineSaver(
            configuration: configuration,
            storage: tower.storage,
            downloader: tower.downloader,
            sdkDownloader: sdkDownloader,
            connectionStateResource: connectionStateResource,
            cleanUpController: tower.cleanUpController
        )
    }

    @MainActor
    func makeBackgroudModesController(container: AuthenticatedDependencyContainer) -> ApplicationStateOperationsController {
        let myFilesUploadOperationInteractor = MyFilesUploadOperationInteractor(
            storage: container.tower.storage,
            interactor: container.tower.fileUploader
        )
        var operationInteractors: [OperationInteractor] = [
            myFilesUploadOperationInteractor,
            container.pickersContainer.photoPickerInteractor
        ]

        let photosUploadOperationInteractor = PhotosUploadOperationInteractor(
            uploadingFiles: container.photosContainer.uploadingPhotosRepository.getPhotos,
            interactor: container.photosContainer.uploader
        )
        operationInteractors.append(photosUploadOperationInteractor)

        if let sdkFilesDownloader = container.tower.getSdkFileDownloader() {
            let sdkOperationsInteractor = SDKFilesDownloadOperationInteractor(downloader: sdkFilesDownloader)
            operationInteractors.append(sdkOperationsInteractor)
        }
        if let sdkPhotosDownloader = container.tower.getSdkPhotoDownloader() {
            let sdkOperationsInteractor = SDKFilesDownloadOperationInteractor(downloader: sdkPhotosDownloader)
            operationInteractors.append(sdkOperationsInteractor)
        }
        if let sdkUploader = container.tower.getSdkFileUploader() {
            let sdkOperationsInteractor = SDKFilesUploadOperationInteractor(uploader: sdkUploader)
            operationInteractors.append(sdkOperationsInteractor)
        }
        // TODO(SDK): add photos uploader when ready

        let operationsInteractor = AggregatedOperationInteractor(interactors: operationInteractors)
        #if SUPPORTS_BACKGROUND_UPLOADS
        let processingController = ProcessingBackgroundOperationController(
            operationInteractor: operationsInteractor,
            taskResource: ProcessingExtensionBackgroundTaskResourceImpl()
        )
        let backgroundOperationController = ExtensionBackgroundOperationController(
            processingController: processingController,
            extensionStateController: extensionTaskStateController,
            operationInteractor: uploadOperationInteractor,
            taskResource: ExtensionBackgroundTaskResourceImpl()
        )
        #else
        let backgroundOperationController = ExtensionBackgroundOperationController(
            extensionStateController: container.extensionTaskStateController,
            operationInteractor: operationsInteractor,
            taskResource: ExtensionBackgroundTaskResourceImpl()
        )
        #endif

        return ApplicationStateOperationsController(
            applicationStateResource: iOSApplicationRunningStateResource(),
            backgroundOperationController: backgroundOperationController
        )
    }
}
