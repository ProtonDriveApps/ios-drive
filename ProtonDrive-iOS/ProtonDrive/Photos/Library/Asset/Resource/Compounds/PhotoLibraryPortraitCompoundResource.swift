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

import PDCore
import Photos

enum PhotoLibraryPortraitPhotoFilesResourceError: Error {
    case invalidResources
}

final class PhotoLibraryPortraitCompoundResource: PhotoLibraryCompoundResource {
    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        return try await executePortraitPhoto(with: identifier, asset: asset)
    }

    private func executePortraitPhoto(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let resources = PHAssetResource.assetResources(for: asset).filter { $0.isImage() }
        let originalFilename = try nameResource.getFilename(from: resources)
        
        let modifiedPhotoAsset = try await getModified(identifier: identifier, asset: asset, resources: resources, originalFilename: originalFilename)
        
        return [PhotoAssetCompound(primary: modifiedPhotoAsset, secondary: [])]
    }

    private func getModified(identifier: PhotoIdentifier, asset: PHAsset, resources: [PHAssetResource], originalFilename: String) async throws -> PhotoAsset {
        let adjustedResource = resources.first(where: { $0.isAdjustedImage() })
        let originalResource = resources.first(where: { $0.isOriginalImage() })

        guard let resource = adjustedResource ?? originalResource else {
            throw PhotoLibraryPortraitPhotoFilesResourceError.invalidResources
        }

        let photoAssetData = PhotoAssetData(identifier: identifier, asset: asset, resource: resource, originalFilename: originalFilename, fileExtension: try resource.getNormalizedFilename().fileExtension(), isOriginal: true)

        return try await assetResource.executePhoto(with: photoAssetData)
    }
}
