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
import PDClient

public struct ThumbnailLoaderFactory {
    public init() {}
    
    // Legacy thumbnail downloader by default
    func makeFileThumbnailLoader(
        tower: Tower?,
        storage: StorageManager,
        cloudSlot: CloudSlotProtocol,
        client: PDClient.Client,
        performanceMetricsController: PerformanceMetricsControllerProtocol?
    ) -> CancellableThumbnailLoader {
        let repository = FileNodeThumbnailRepository(store: storage)
        let typeStrategy = DefaultThumbnailTypeStrategy()
        return makeLoader(
            storage: storage,
            cloudSlot: cloudSlot,
            client: client,
            repository: repository,
            typeStrategy: typeStrategy,
            performanceMetricsController: performanceMetricsController,
            getSDKDownloader: { [weak tower] in return tower?.getSdkThumbnailsDownloaderForFiles() },
            useSDK: { [weak tower] in return tower?.getSdkThumbnailsDownloaderForFiles() != nil }
        )
    }

    public func makePhotoSmallThumbnailLoader(tower: Tower) -> ThumbnailLoader {
        let typeStrategy = DefaultThumbnailTypeStrategy()
        let repository = PhotoNodeThumbnailRepository(store: tower.storage, typeStrategy: typeStrategy)
        return makeLoader(
            storage: tower.storage,
            cloudSlot: tower.cloudSlot,
            client: tower.client,
            repository: repository,
            typeStrategy: typeStrategy,
            performanceMetricsController: tower.performanceMetricsController,
            getSDKDownloader: { [weak tower] in return tower?.getSdkThumbnailsDownloaderForPhotos() },
            useSDK: { [weak tower] in return tower?.getSdkThumbnailsDownloaderForPhotos() != nil }
        )
    }

    public func makePhotoBigThumbnailLoader(tower: Tower) -> ThumbnailLoader {
        let typeStrategy = PhotoBigThumbnailTypeStrategy()
        let repository = PhotoNodeThumbnailRepository(store: tower.storage, typeStrategy: typeStrategy)
        return makeLoader(
            storage: tower.storage,
            cloudSlot: tower.cloudSlot,
            client: tower.client,
            repository: repository,
            typeStrategy: typeStrategy,
            performanceMetricsController: tower.performanceMetricsController,
            getSDKDownloader: { [weak tower] in return tower?.getSdkThumbnailsDownloaderForPhotos() },
            useSDK: { [weak tower] in return tower?.getSdkThumbnailsDownloaderForPhotos() != nil }
        )
    }

    private func makeLoader(
        storage: StorageManager,
        cloudSlot: CloudSlotProtocol,
        client: PDClient.Client,
        repository: NodeThumbnailRepository,
        typeStrategy: ThumbnailTypeStrategy,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        getSDKDownloader: @escaping () -> SDKThumbnailsDownloaderProtocol?,
        useSDK: @escaping () -> Bool
    ) -> DispatchedAsyncThumbnailLoader {
        let thumbnailsOperatiosFactory = LoadThumbnailOperationsFactory(
            store: storage,
            cloud: cloudSlot,
            client: client,
            thumbnailRepository: repository,
            typeStrategy: typeStrategy,
            performanceMetricsController: performanceMetricsController,
            getSDKDownloader: getSDKDownloader
        )
        let asyncLoader = AsyncThumbnailLoader(operationsFactory: thumbnailsOperatiosFactory, useSDK: useSDK)
        return DispatchedAsyncThumbnailLoader(thumbnailLoader: asyncLoader)
    }
}
