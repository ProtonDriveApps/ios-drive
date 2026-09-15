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

import CoreData
import PDCore
import PDSDKCore

public struct SDKThumbnailsDownloaderFactory {
    public init() {}

    public func makeThumbnailDownloader(
        contextPool: SyncManagedObjectContextPool,
        fileOperationPerformer: FileOperationPerformer,
        photoOperationPerformer: PhotosOperationPerformer,
        volumeIDRepository: VolumeIDRepository
    ) -> SDKThumbnailsDownloaderProtocol {
        let managedObjectContext = contextPool.acquire()
        let fileInteractor = FilesThumbnailsDownloadInteractor(
            operationPerformer: fileOperationPerformer,
            cacheResource: ThumbnailsDownloadLocalCache(managedObjectContext: managedObjectContext),
            managedObjectContext: managedObjectContext,
            tokenStore: ThumbnailsDownloadTokensCache()
        )
        let photoInteractor = PhotoThumbnailsDownloadInteractor(
            operationPerformer: photoOperationPerformer,
            cacheResource: ThumbnailsDownloadLocalCache(managedObjectContext: managedObjectContext),
            managedObjectContext: managedObjectContext,
            tokenStore: ThumbnailsDownloadTokensCache()
        )

        return SDKThumbnailsDownloader(
            context: managedObjectContext,
            contextPool: contextPool,
            fileInteractor: fileInteractor,
            photoInteractor: photoInteractor,
            volumeIDRepository: volumeIDRepository
        )
    }
}
