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

    @MainActor
    func makeSDKUploader(performer: FileOperationPerformer) -> SDKFileUploaderProtocol {
        uploaderFactory.makeFileUploader(
            bytesCounterResource: ThreadSafeBytesCounterResource(),
            operationPerformer: performer
        )
    }

    @MainActor
    func makeSDKThumbnailsDownloader(
        fileOperationPerformer: FileOperationPerformer,
        photoOperationPerformer: PhotosOperationPerformer
    ) -> SDKThumbnailsDownloaderProtocol {
        SDKThumbnailsDownloaderFactory().makeThumbnailDownloader(
            contextPool: tower.storage.synchronousContextPool,
            fileOperationPerformer: fileOperationPerformer,
            photoOperationPerformer: photoOperationPerformer,
            volumeIDRepository: tower.storage
        )
    }

    @MainActor
    func makeSDKDownloader(performer: FileOperationPerformer) -> SDKFileDownloaderProtocol {
        SDKDownloaderFactory().makeFileDownloader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
    }

    @MainActor
    func makeSDKPhotoDownloader(performer: PhotosOperationPerformer) -> SDKFileDownloaderProtocol {
        SDKDownloaderFactory().makePhotoDownloader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
    }

    @MainActor
    func makeSDKPhotoUploader(
        performer: PhotosOperationPerformer,
        photoUploadedNotifier: PhotoUploadedNotifier,
        skippableCache: PhotosSkippableCache,
        failedPhotosResource: DeletedPhotosIdentifierStoreResource
    ) -> SDKFileUploaderProtocol {
        uploaderFactory.makePhotoUploader(
            bytesCounterResource: ThreadSafeBytesCounterResource(),
            operationPerformer: performer,
            photoUploadedNotifier: photoUploadedNotifier,
            skippableCache: skippableCache,
            failedPhotosResource: failedPhotosResource,
            photoMoc: tower.storage.photosSecondaryBackgroundContext
        )
    }

    typealias SDKDownloaders = (file: SDKFileDownloaderProtocol, photo: SDKFileDownloaderProtocol)
    func makeOfflineSavers(
        connectionStateResource: ConnectionStateResource,
        sdkDownloaders: SDKDownloaders
    ) -> [OfflineSaverProtocol] {
        let fileSaver = makeSDKOfflineSaver(
            tower: tower,
            sdkDownloader: sdkDownloaders.file,
            connectionStateResource: connectionStateResource,
            configuration: .onlyMyFiles
        )
        let photoSaver = makeSDKOfflineSaver(
            tower: tower,
            sdkDownloader: sdkDownloaders.photo,
            connectionStateResource: connectionStateResource,
            configuration: .onlyPhotos
        )
        return [fileSaver, photoSaver]
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
    func makeBackgroundModesController(container: AuthenticatedDependencyContainer) -> ApplicationStateOperationsController {
        var operationInteractors: [OperationInteractor] = [
            container.pickersContainer.photoPickerInteractor
        ]

        let fileDownloadInteractor = SDKFilesDownloadOperationInteractor(downloader: tower.sdkObjects.fileDownloader)
        operationInteractors.append(fileDownloadInteractor)
        let photoDownloadInteractor = SDKFilesDownloadOperationInteractor(downloader: tower.sdkObjects.photoDownloader)
        operationInteractors.append(photoDownloadInteractor)
        let fileUploadInteractor = SDKFilesUploadOperationInteractor(uploader: tower.sdkObjects.fileUploader)
        operationInteractors.append(fileUploadInteractor)
        let photoUploadInteractor = SDKFilesUploadOperationInteractor(uploader: tower.sdkObjects.photoUploader)
        operationInteractors.append(photoUploadInteractor)

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
