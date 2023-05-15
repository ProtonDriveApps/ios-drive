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

struct PhotoAssetData {
    let identifier: PhotoIdentifier
    let resource: PHAssetResource
    let filename: String
    let isOriginal: Bool
}

protocol PhotoLibraryAssetResource {
    func execute(with data: PhotoAssetData) async throws -> PhotoAsset
}

final class LocalPhotoLibraryAssetResource: PhotoLibraryAssetResource {
    private let contentResource: PhotoLibraryFileContentResource
    private let assetFactory: PhotoAssetFactory

    init(contentResource: PhotoLibraryFileContentResource, assetFactory: PhotoAssetFactory) {
        self.contentResource = contentResource
        self.assetFactory = assetFactory
    }

    func execute(with data: PhotoAssetData) async throws -> PhotoAsset {
        async let url = contentResource.copyFile(with: data.resource)
        async let hash = contentResource.createHash(with: data.resource)
        return assetFactory.makeAsset(
            identifier: data.identifier,
            url: try await url,
            hash: try await hash,
            filename: data.filename,
            isOriginal: data.isOriginal
        )
    }
}
