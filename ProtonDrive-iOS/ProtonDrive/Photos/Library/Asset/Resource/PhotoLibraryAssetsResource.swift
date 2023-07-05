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

import Photos
import PDCore

enum PhotoLibraryAssetsResourceError: Error {
    case invalidIdentifier
    case invalidMediaType
}

protocol PhotoLibraryAssetsResource {
    func execute(with identifier: PhotoIdentifier) async throws -> [PhotoAssetCompound]
}

final class LocalPhotoLibraryAssetsResource: PhotoLibraryAssetsResource {
    private let plainResource: PhotoLibraryCompoundResource
    private let livePhotoResource: PhotoLibraryCompoundResource
    private let burstResource: PhotoLibraryCompoundResource

    init(plainResource: PhotoLibraryCompoundResource, livePhotoResource: PhotoLibraryCompoundResource, burstResource: PhotoLibraryCompoundResource) {
        self.plainResource = plainResource
        self.livePhotoResource = livePhotoResource
        self.burstResource = burstResource
    }

    func execute(with identifier: PhotoIdentifier) async throws -> [PhotoAssetCompound] {
        let options = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier.localIdentifier], options: options)
        guard let asset = assets.firstObject else {
            throw PhotoLibraryAssetsResourceError.invalidIdentifier
        }

        if asset.burstIdentifier != nil {
            return try await burstResource.execute(with: identifier, asset: asset)
        } else {
            return try await execute(identifier: identifier, asset: asset)
        }
    }

    private func execute(identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        if asset.mediaSubtypes.contains(.photoLive) {
            return try await livePhotoResource.execute(with: identifier, asset: asset)
        } else {
            return try await plainResource.execute(with: identifier, asset: asset)
        }
    }
}
