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
import PDCore
import PDSDKCore

public struct SDKFileUploaderFactory {
    private let encoder: JSONEncoder
    private let managedObjectContext: NSManagedObjectContext
    private let protectionResource: ProtectionResource
    private let thumbnailProvider: SynchronizedThumbnailProviderProtocol

    public init(
        encoder: JSONEncoder,
        managedObjectContext: NSManagedObjectContext,
        protectionResource: ProtectionResource,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol
    ) {
        self.encoder = encoder
        self.managedObjectContext = managedObjectContext
        self.protectionResource = protectionResource
        self.thumbnailProvider = thumbnailProvider
    }

    @MainActor public func makeFileUploader(
        bytesCounterResource: BytesCounterResource,
        operationPerformer: FileOperationPerformer
    ) -> SDKFileUploaderProtocol {
        let cacheResource = FileUploaderCache(encoder: encoder, managedObjectContext: managedObjectContext)
        let interactor = FileUploadInteractor(
            cacheResource: cacheResource,
            managedObjectContext: managedObjectContext,
            operationPerformer: operationPerformer,
            protectionResource: protectionResource,
            thumbnailProvider: thumbnailProvider,
            operationsStore: UploadOperationsStore()
        )

        return SDKFileUploader(
            bytesCounterResource: bytesCounterResource,
            cacheResource: cacheResource,
            interactor: interactor,
            protectionResource: protectionResource,
            tokenStore: CancellationTokenStore()
        )
    }

    @MainActor public func makePhotoUploader(
        bytesCounterResource: BytesCounterResource,
        operationPerformer: PhotosOperationPerformer,
        photoUploadedNotifier: PhotoUploadedNotifier,
        skippableCache: PhotosSkippableCache,
        failedPhotosResource: DeletedPhotosIdentifierStoreResource,
        photoMoc: NSManagedObjectContext
    ) -> SDKFileUploaderProtocol {
        let cacheResource = FileUploaderCache(encoder: encoder, managedObjectContext: managedObjectContext)
        let interactor = PhotoUploadInteractor(
            cacheResource: cacheResource,
            failedPhotosResource: failedPhotosResource,
            managedObjectContext: photoMoc,
            operationPerformer: operationPerformer,
            photoUploadedNotifier: photoUploadedNotifier,
            protectionResource: protectionResource,
            skippableCache: skippableCache,
            thumbnailProvider: thumbnailProvider,
            operationsStore: UploadOperationsStore()
        )
        return SDKFileUploader(
            bytesCounterResource: bytesCounterResource,
            cacheResource: cacheResource,
            interactor: interactor,
            protectionResource: protectionResource,
            tokenStore: CancellationTokenStore(),
            localNotificationResource: FileUploadNotificationResource()
        )
    }
}
