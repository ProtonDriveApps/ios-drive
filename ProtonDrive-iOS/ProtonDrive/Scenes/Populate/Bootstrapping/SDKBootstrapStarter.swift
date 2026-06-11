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
import PDCoreIOS
import PDSDKCore
import PDSDKCoreiOS
import ProtonCoreKeymaker

final class SDKBootstrapStarter: AppBootstrapper {
    private let dependencies: Dependencies
    private var tower: Tower { dependencies.tower }
    private var featureFlagsController: FeatureFlagsControllerProtocol { dependencies.featureFlagsController }
    private let factory: AuthenticatedDependenciesFactory

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        self.factory = AuthenticatedDependenciesFactory(keymaker: dependencies.keymaker, tower: dependencies.tower)
    }

    func bootstrap() async throws {
        await measure(message: "Initialize SDK", domain: .applicationBootstrap) {
            async let performerInitializer = initializeSDKOperationPerformer()
            async let photosPerformerInitializer = initializeSDKPhotosOperationPerformer()
            let (performer, photosPerformer) = await (performerInitializer, photosPerformerInitializer)

            initializeSDKNodeOperationPerformer(performer: performer)
            await withTaskGroup { [weak self] group in
                group.addTask { await self?.initializeSDKUploader(performer: performer) }
                group.addTask {
                    await self?.initializeDownloaderAndOfflineSaver(
                        performer: performer,
                        photosPerformer: photosPerformer
                    )
                }
                group.addTask { await self?.initializeThumbnailDownloader(performer: performer) }
                group.addTask { await self?.initializePhotosThumbnailDownloader(performer: photosPerformer) }
                group.addTask { await self?.initializePhotosUploader(performer: photosPerformer) }
            }
            initializeNodeTreeOperator()
        }
    }
}

// MARK: - Files
extension SDKBootstrapStarter {
    private func initializeSDKOperationPerformer() async -> FileOperationPerformer? {
        guard
            featureFlagsController.hasSDKUploadMain ||
            featureFlagsController.hasSDKDownloadMain ||
            featureFlagsController.hasSDKDownloadPhoto ||
            featureFlagsController.hasSDKNodeOperations
        else { return nil }
        return try? await SDKOperationPerformerFactory().makeFilePerformer(tower: tower)
    }

    private func initializeSDKNodeOperationPerformer(performer: FileOperationPerformer?) {
        guard let performer, featureFlagsController.hasSDKNodeOperations else { return }
        let operationPerformer = NodeOperationPerformer(
            dependencies: .init(
                performer: performer,
                context: tower.storage.backgroundContext
            )
        )
        tower.set(sdkNodeOperationPerformer: operationPerformer)
    }

    private func initializeSDKUploader(performer: FileOperationPerformer?) async {
        guard featureFlagsController.hasSDKUploadMain else { return }
        if let sdkUploader = await factory.makeSDKUploader(performer: performer) {
            tower.set(sdkFileUploader: sdkUploader)
            Log.info("Initialized sdkUploader", domain: .sdk)
        }
    }

    private func initializeDownloaderAndOfflineSaver(
        performer: FileOperationPerformer?,
        photosPerformer: PhotosOperationPerformer?
    ) async {
        let sdkDownloader = await factory.makeSDKDownloader(performer: performer)
        if let sdkDownloader {
            tower.set(sdkFileDownloader: sdkDownloader)
            Log.info("Initialized sdkDownloader", domain: .sdk)
        }
        let photoDownloader = await initializeSDKPhotoDownloader(performer: photosPerformer)
        if let photoDownloader {
            tower.set(sdkPhotoDownloader: photoDownloader)
            Log.info("Initialized sdkPhotoDownloader", domain: .sdk)
        }
        tower.offlineSavers = factory.makeOfflineSavers(
            populatedController: dependencies.populatedController,
            connectionStateResource: dependencies.connectionStateResource,
            sdkDownloaders: (sdkDownloader, photoDownloader),
            hasSDKDownloadMain: featureFlagsController.hasSDKDownloadMain,
            hasSDKDownloadPhoto: featureFlagsController.hasSDKDownloadPhoto
        )
    }

    private func initializeThumbnailDownloader(performer: FileOperationPerformer?) async {
        guard
            featureFlagsController.hasSDKDownloadMain,
            let downloader = await factory.makeSDKThumbnailsDownloader(performer: performer)
        else { return }
        Log.info("Initialized sdkThumbnailsDownloader", domain: .sdk)
        tower.set(sdkThumbnailsDownloaderForFiles: downloader)
    }
}

// MARK: - Photos
extension SDKBootstrapStarter {
    private func initializeSDKPhotosOperationPerformer() async -> PhotosOperationPerformer? {
        guard featureFlagsController.hasSDKDownloadPhoto else { return nil }
        return try? await SDKOperationPerformerFactory().makePhotoPerformer(tower: tower)
    }

    private func initializeSDKPhotoDownloader(performer: PhotosOperationPerformer?) async -> SDKFileDownloaderProtocol? {
        guard
            featureFlagsController.hasSDKDownloadPhoto,
            let downloader = await factory.makeSDKPhotoDownloader(performer: performer)
        else { return nil }
        return downloader
    }

    private func initializePhotosThumbnailDownloader(performer: PhotosOperationPerformer?) async {
        guard
            let downloader = await factory.makeSDKPhotosThumbnailsDownloader(tower: tower, performer: performer),
            featureFlagsController.hasSDKDownloadPhoto
        else { return }
        Log.info("Initialized sdkPhotosThumbnailsDownloader", domain: .sdk)
        tower.set(sdkThumbnailsDownloaderForPhotos: downloader)
    }

    private func initializePhotosUploader(performer: PhotosOperationPerformer?) async {
        guard featureFlagsController.hasSDKUploadPhoto else { return }
        if let uploader = await factory.makeSDKPhotoUploader(
            performer: performer,
            photoUploadedNotifier: dependencies.photoUploadedNotifier,
            skippableCache: dependencies.skippableCache,
            failedPhotosResource: dependencies.failedPhotosResource
        ) {
            Log.info("Initialized sdkPhotoUploader", domain: .sdk)
            tower.set(sdkPhotoUploader: uploader)
        }
    }
}

extension SDKBootstrapStarter {
    private func initializeNodeTreeOperator() {
        let downloaders: [DownloaderProtocol?] = [tower.downloader, tower.getSdkFileDownloader()]
        let treeTrashHandler = NodeTreeTrashHandler(downloaders: downloaders.compactMap { $0 })
        let treeOperator = NodeTreeOperator(dependencies: .init(trashHandler: treeTrashHandler))
        tower.set(nodeTreeOperator: treeOperator)
        tower.set(treeTrashHandler: treeTrashHandler)
    }
}

extension SDKBootstrapStarter {
    struct Dependencies {
        let tower: Tower
        let featureFlagsController: FeatureFlagsControllerProtocol
        let populatedController: PopulatedStateControllerProtocol
        let connectionStateResource: ConnectionStateResource
        let keymaker: Keymaker
        let photoUploadedNotifier: PhotoUploadedNotifier
        let skippableCache: PhotosSkippableCache
        let failedPhotosResource: DeletedPhotosIdentifierStoreResource
    }
}
