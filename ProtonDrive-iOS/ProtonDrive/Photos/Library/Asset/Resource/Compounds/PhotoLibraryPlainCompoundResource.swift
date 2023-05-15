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

final class PhotoLibraryPlainCompoundResource: PhotoLibraryCompoundResource {
    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let allResources = PHAssetResource.assetResources(for: asset)
        let filename = try nameResource.getFilename(from: allResources)
        let filteredResources = allResources.filter { $0.isImage() || $0.isVideo() }
        return try await filteredResources.asyncMap {
            try await loadAsset(with: identifier, resource: $0, filename: filename)
        }
    }

    private func loadAsset(with identifier: PhotoIdentifier, resource: PHAssetResource, filename: String) async throws -> PhotoAssetCompound {
        let isOriginal = resource.isOriginalImage() || resource.isOriginalVideo()
        let data = PhotoAssetData(identifier: identifier, resource: resource, filename: filename, isOriginal: isOriginal)
        let asset = try await assetResource.execute(with: data)
        return PhotoAssetCompound(primary: asset, secondary: [])
    }
}
