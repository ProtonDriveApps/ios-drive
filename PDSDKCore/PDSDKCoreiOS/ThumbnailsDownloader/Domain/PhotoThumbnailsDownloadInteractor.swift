// Copyright (c) 2026 Proton AG
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
import Foundation
import PDCore
import PDSDKCore
import ProtonDriveSDK

final class PhotoThumbnailsDownloadInteractor: ThumbnailsDownloadInteractor {
    private let downloader: ThumbnailsBatchDownloader

    init(
        operationPerformer: PhotosOperationPerformer,
        cacheResource: ThumbnailsDownloadLocalCache,
        managedObjectContext: NSManagedObjectContext,
        tokenStore: ThumbnailsDownloadTokensCache
    ) {
        self.downloader = ThumbnailsBatchDownloader(
            cacheResource: cacheResource,
            managedObjectContext: managedObjectContext,
            tokenStore: tokenStore,
            streamFactory: { uids, type, token, moc in
                operationPerformer.downloadThumbnailsStream(
                    photoUids: uids,
                    type: type,
                    cancellationToken: token,
                    moc: moc
                )
            }
        )
    }

    func downloadThumbnail(
        file identifier: AnyVolumeIdentifier,
        type: ThumbnailType
    ) async throws -> AnyVolumeIdentifier? {
        try await downloader.downloadThumbnail(file: identifier, type: type)
    }

    func cancel(file identifier: AnyVolumeIdentifier, type: ThumbnailType) async {
        await downloader.cancel(file: identifier, type: type)
    }
}
