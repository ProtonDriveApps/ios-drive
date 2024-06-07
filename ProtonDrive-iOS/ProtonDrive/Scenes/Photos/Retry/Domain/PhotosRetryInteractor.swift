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

protocol PhotosRetryInteractorProtocol {
    func fetchAssets(ofSize size: CGSize) async -> ([FullPreview], Int)
    func retryUpload()
    func clearDeletedStorage()
}

final class PhotosRetryInteractor: PhotosRetryInteractorProtocol {
    
    private let deletedStoreResource: DeletedPhotosIdentifierStoreResource
    private let previewProvider: PhotoLibraryPreviewResourceProtocol
    private let retryTriggerController: PhotoLibraryLoadRetryTriggerController
    
    init(
        deletedStoreResource: DeletedPhotosIdentifierStoreResource,
        previewProvider: PhotoLibraryPreviewResourceProtocol,
        retryTriggerController: PhotoLibraryLoadRetryTriggerController
    ) {
        self.deletedStoreResource = deletedStoreResource
        self.previewProvider = previewProvider
        self.retryTriggerController = retryTriggerController
    }
    
    func fetchAssets(ofSize size: CGSize) async -> ([FullPreview], Int) {
        let total = deletedStoreResource.getCloudIdentifiers()
        
        let previews = await previewProvider
            .execute(total.compactMap({ $0 }), size: size)
            .map {
                FullPreview(
                    localIdentifier: $0.localIdentifier,
                    filename: $0.originalFilename,
                    imageData: $0.imageData
                )
            }

        return (previews, total.count - previews.count)
    }
    
    func clearDeletedStorage() {
        deletedStoreResource.reset()
    }
    
    func retryUpload() {
        retryTriggerController.retry()
    }
}
