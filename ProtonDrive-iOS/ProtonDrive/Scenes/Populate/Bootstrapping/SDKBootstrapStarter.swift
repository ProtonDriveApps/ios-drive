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
            do {
                async let performerInitializer = initializeSDKOperationPerformer()
                async let photosPerformerInitializer = initializeSDKPhotosOperationPerformer()
                let (performer, photosPerformer) = try await (performerInitializer, photosPerformerInitializer)
                
                let nodeOperationPerformer = initializeSDKNodeOperationPerformer(performer: performer, photoPerformer: photosPerformer)
                async let fileUploaderInitializer = factory.makeSDKUploader(performer: performer)
                async let fileDownloaderInitializer = factory.makeSDKDownloader(performer: performer)
                async let thumbnailDownloaderInitializer = factory.makeSDKThumbnailsDownloader(
                    fileOperationPerformer: performer,
                    photoOperationPerformer: photosPerformer
                )
                async let revisionUploaderInitializer = SDKRevisionUploaderFactory().makeUploader(
                    operationPerformer: performer,
                    managedObjectContext: tower.storage.backgroundContext
                )
                
                async let photoUploaderInitializer = initializePhotosUploader(performer: photosPerformer)
                async let photoDownloaderInitializer = factory.makeSDKPhotoDownloader(performer: photosPerformer)
                
                let sdkObjects = SDKObjects(
                    fileDownloader: await fileDownloaderInitializer,
                    fileUploader: await fileUploaderInitializer,
                    nodeOperationPerformer: nodeOperationPerformer,
                    photoDownloader: await photoDownloaderInitializer,
                    photoUploader: await photoUploaderInitializer,
                    revisionUploader: await revisionUploaderInitializer,
                    thumbnailDownloader: await thumbnailDownloaderInitializer
                )
                tower.set(sdkObjects: sdkObjects)
                tower.offlineSavers = factory.makeOfflineSavers(
                    connectionStateResource: dependencies.connectionStateResource,
                    sdkDownloaders: (sdkObjects.fileDownloader, sdkObjects.photoDownloader)
                )
                
                initializeNodeTreeOperator(sdkDownloader: sdkObjects.fileDownloader)
            } catch {
                fatalError("Initialize SDK performer failed")
            }
        }
    }
}

// MARK: - Files
extension SDKBootstrapStarter {
    private func initializeSDKOperationPerformer() async throws -> FileOperationPerformer {
        return try await SDKOperationPerformerFactory().makeFilePerformer(tower: tower)
    }

    private func initializeSDKNodeOperationPerformer(
        performer: FileOperationPerformer,
        photoPerformer: PhotosOperationPerformer
    ) -> NodeOperationPerformer? {
        guard featureFlagsController.needsSDKNodeOperationPerformer else { return nil }
        let operationPerformer = NodeOperationPerformer(
            dependencies: .init(
                performer: performer,
                photoPerformer: photoPerformer,
                context: tower.storage.backgroundContext
            )
        )
        return operationPerformer
    }
}

// MARK: - Photos
extension SDKBootstrapStarter {
    private func initializeSDKPhotosOperationPerformer() async throws -> PhotosOperationPerformer {
        try await SDKOperationPerformerFactory().makePhotoPerformer(tower: tower)
    }

    private func initializePhotosUploader(performer: PhotosOperationPerformer) async -> SDKFileUploaderProtocol {
        await factory.makeSDKPhotoUploader(
            performer: performer,
            photoUploadedNotifier: dependencies.photoUploadedNotifier,
            skippableCache: dependencies.skippableCache,
            failedPhotosResource: dependencies.failedPhotosResource
        )
    }
}

extension SDKBootstrapStarter {
    private func initializeNodeTreeOperator(sdkDownloader: SDKFileDownloaderProtocol) {
        let treeTrashHandler = NodeTreeTrashHandler(downloader: sdkDownloader)
        let treeOperator = NodeTreeOperator(dependencies: .init(trashHandler: treeTrashHandler))
        tower.set(nodeTreeOperator: treeOperator)
        tower.set(treeTrashHandler: treeTrashHandler)
    }
}

extension SDKBootstrapStarter {
    struct Dependencies {
        let tower: Tower
        let featureFlagsController: FeatureFlagsControllerProtocol
        let connectionStateResource: ConnectionStateResource
        let keymaker: Keymaker
        let photoUploadedNotifier: PhotoUploadedNotifier
        let skippableCache: PhotosSkippableCache
        let failedPhotosResource: DeletedPhotosIdentifierStoreResource
    }
}
