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

import CoreData
import PDCore
import PDCoreIOS

struct ThumbnailsControllerFactory {
    func makeSmallThumbnailsController(tower: Tower) -> ThumbnailsController {
        let thumbnailLoader = ThumbnailLoaderFactory().makePhotoSmallThumbnailLoader(tower: tower)
        return makeThumbnailsController(thumbnailLoader: thumbnailLoader)
    }

    func makeBigThumbnailsController(tower: Tower) -> ThumbnailsController {
        let thumbnailLoader = ThumbnailLoaderFactory().makePhotoBigThumbnailLoader(tower: tower)
        return makeThumbnailsController(thumbnailLoader: thumbnailLoader)
    }

    // swiftlint:disable:next function_parameter_count
    func makeThumbnailController(
        tower: Tower,
        thumbnailsController: ThumbnailsController,
        urlsController: ThumbnailURLsController,
        metadataController: MetadataControllerProtocol,
        synchronousRepository: SynchronousThumbnailRepository,
        performanceMetricsController: PerformanceMetricsControllerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol,
        id: PhotoId,
        type: ThumbnailType
    ) -> ThumbnailController {
        let managedObjectContext = getManagedObjectContext(tower: tower)
        let asynchronousRepository = DatabaseAsynchronousThumbnailRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage, type: type)
        let canUseSDK = tower.getSdkThumbnailsDownloaderForPhotos() != nil
        return LocalThumbnailController(
            thumbnailsController: thumbnailsController,
            urlsController: urlsController,
            metadataController: metadataController,
            synchronousRepository: synchronousRepository,
            asynchronousRepository: asynchronousRepository,
            performanceMetricsController: performanceMetricsController,
            canUseSDK: canUseSDK,
            id: id
        )
    }

    private func getManagedObjectContext(tower: Tower) -> NSManagedObjectContext {
        tower.storage.backgroundContext
    }

    func makeUrlsController(
        tower: Tower,
        type: ThumbnailType
    ) -> ThumbnailURLsController {
        let managedObjectContext = getManagedObjectContext(tower: tower)
        let idsDataSource = LocalPhotoThumbnailIdsRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let listInteractor = ThumbnailsListFactory().makeInteractor(client: tower.client)
        let interactor = RemoteThumbnailURLsInteractor(listInteractor: listInteractor, updateRepository: tower.cloudSlot, idsDataSource: idsDataSource, type: type)
        let facade = ThumbnailURLsSerialFetchingFacade(interactor: interactor)
        return FetchingThumbnailURLsController(facade: facade)
    }

    private func makeThumbnailsController(thumbnailLoader: ThumbnailLoader) -> ThumbnailsController {
        LocalThumbnailsController(thumbnailLoader: thumbnailLoader)
    }
}
