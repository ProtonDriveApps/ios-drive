// Copyright (c) 2024 Proton AG
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
import PDLocalization

protocol PhotosRetryInteractorProtocol {
    func fetchAssets(ofSize size: CGSize) async -> ([FullPreview], Int)
    func retryUpload()
    func clearDeletedStorage()
    func markFailedAsSkippable(assets: [FullPreview])
}

final class PhotosRetryInteractor: PhotosRetryInteractorProtocol {
    
    private let deletedStoreResource: DeletedPhotosIdentifierStoreResource
    private let previewProvider: PhotoLibraryPreviewResourceProtocol
    private let retryTriggerController: PhotoLibraryLoadRetryTriggerController
    private let skippableCache: PhotosSkippableCache

    init(
        deletedStoreResource: DeletedPhotosIdentifierStoreResource,
        previewProvider: PhotoLibraryPreviewResourceProtocol,
        retryTriggerController: PhotoLibraryLoadRetryTriggerController,
        skippableCache: PhotosSkippableCache
    ) {
        self.deletedStoreResource = deletedStoreResource
        self.previewProvider = previewProvider
        self.retryTriggerController = retryTriggerController
        self.skippableCache = skippableCache
    }
    
    func fetchAssets(ofSize size: CGSize) async -> ([FullPreview], Int) {
        let results = deletedStoreResource.getCloudIdentifiersAndError()
        // There can be multiple failed items with the same cloud identifier. We will show only one of them in the view to avoid confusion.
        let identifiersSet = Set(results.compactMap { $0.cloudIdentifier })
        let uniqueIdentifiers = Array(identifiersSet).sorted(by: >)
        
        let previews = await previewProvider
            .execute(uniqueIdentifiers, size: size)
            .map { preview in
                let error = results.first(where: { $0.cloudIdentifier == preview.cloudIdentifier && $0.error != nil })?.error
                return FullPreview(
                    localIdentifier: preview.localIdentifier,
                    cloudIdentifier: preview.cloudIdentifier,
                    filename: preview.originalFilename,
                    imageData: preview.imageData,
                    errorMessage: error?.localizedDescription,
                    creationDate: preview.creationDate,
                    modificationDate: preview.modificationDate
                )
            }

        return (previews, uniqueIdentifiers.count - previews.count)
    }
    
    func clearDeletedStorage() {
        deletedStoreResource.reset()
    }
    
    func markFailedAsSkippable(assets: [FullPreview]) {
        var batch = [PhotoAssetMetadata.iOSPhotos: Int]()
        for asset in assets {
            guard let cloudIdentifier = asset.cloudIdentifier else {
                continue
            }
            let identifier = PhotoAssetMetadata.iOSPhotos(identifier: cloudIdentifier, modificationTime: asset.modificationDate)
            batch[identifier] = (batch[identifier] ?? 0) + 1
        }
        skippableCache.batchMarkAsSkippable(batch)
    }
    
    func retryUpload() {
        retryTriggerController.retry()
    }
}
