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

    public func makeFilesThumbnailDownloader(
        operationPerformer: FileOperationPerformer,
        managedObjectContext: NSManagedObjectContext
    ) -> SDKThumbnailsDownloaderProtocol {
        SDKThumbnailsDownloader(
            interactor: FilesThumbnailsDownloadInteractor(
                operationPerformer: operationPerformer,
                cacheResource: ThumbnailsDownloadLocalCache(managedObjectContext: managedObjectContext),
                managedObjectContext: managedObjectContext,
                tokenStore: ThumbnailsDownloadTokensCache()
            )
        )
    }

    public func makePhotosThumbnailDownloader(
        operationPerformer: PhotosOperationPerformer,
        managedObjectContext: NSManagedObjectContext
    ) -> SDKThumbnailsDownloaderProtocol {
        SDKThumbnailsDownloader(
            interactor: PhotoThumbnailsDownloadInteractor(
                operationPerformer: operationPerformer,
                cacheResource: ThumbnailsDownloadLocalCache(managedObjectContext: managedObjectContext),
                managedObjectContext: managedObjectContext,
                tokenStore: ThumbnailsDownloadTokensCache()
            )
        )
    }
}
