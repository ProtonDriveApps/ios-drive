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
    func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset
    func executeVideo(with data: PhotoAssetData) async throws -> PhotoAsset
}

final class LocalPhotoLibraryAssetResource: PhotoLibraryAssetResource {
    private let contentResource: PhotoLibraryFileContentResource
    private let assetFactory: PhotoAssetFactory
    private let exifResource: PhotoLibraryExifResource

    init(contentResource: PhotoLibraryFileContentResource, assetFactory: PhotoAssetFactory, exifResource: PhotoLibraryExifResource) {
        self.contentResource = contentResource
        self.assetFactory = assetFactory
        self.exifResource = exifResource
    }

    func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset {
        let url = try await contentResource.copyFile(with: data.resource)
        return try await execute(with: data, url: url, duration: nil)
    }

    func executeVideo(with data: PhotoAssetData) async throws -> PhotoAsset {
        let url = try await contentResource.copyFile(with: data.resource)
        let duration = contentResource.getVideoDuration(at: url)
        return try await execute(with: data, url: url, duration: duration)
    }

    private func execute(with data: PhotoAssetData, url: URL, duration: Double?) async throws -> PhotoAsset {
        let exif = try await getExif(from: data.resource, url: url)
        let hash = try await contentResource.createHash(with: data.resource)
        let factoryData = PhotoAssetFactoryData(
            identifier: data.identifier,
            url: url,
            hash: hash,
            filename: data.filename,
            exif: exif,
            isOriginal: data.isOriginal,
            duration: duration
        )
        return try assetFactory.makeAsset(from: factoryData)
    }

    private func getExif(from resource: PHAssetResource, url: URL) async throws -> PhotoAsset.Exif {
        if resource.isImage() {
            return try exifResource.getPhotoExif(at: url)
        } else {
            return try await exifResource.getVideoExif(at: url)
        }
    }
}
