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

import Foundation
import PDCore

struct PhotoAssetFactoryData {
    let identifier: PhotoIdentifier
    let url: URL
    let mimeType: MimeType
    let originalFilename: String
    let filenameExtension: String
    let width: Int
    let height: Int
    let exif: PhotoAsset.Exif
    let isOriginal: Bool
    let duration: Double?
    let camera: PhotoAssetMetadata.Camera
    let location: PhotoAssetMetadata.Location?
}

protocol PhotoAssetFactory {
    func makeAsset(from data: PhotoAssetFactoryData) throws -> PhotoAsset
}

final class LocalPhotoAssetFactory: PhotoAssetFactory {
    private let nameStrategy: PhotoLibraryFilenameStrategy

    init(nameStrategy: PhotoLibraryFilenameStrategy) {
        self.nameStrategy = nameStrategy
    }

    func makeAsset(from data: PhotoAssetFactoryData) throws -> PhotoAsset {
        return PhotoAsset(
            url: data.url,
            filename: makeName(from: data),
            mimeType: data.mimeType,
            exif: data.exif,
            metadata: PhotoAssetMetadata(
                media: PhotoAssetMetadata.Media(width: data.width, height: data.height, duration: data.duration),
                camera: data.camera,
                location: data.location,
                iOSPhotos: PhotoAssetMetadata.iOSPhotos(identifier: data.identifier.cloudIdentifier, modificationTime: data.identifier.modifiedDate)
            )
        )
    }

    private func makeName(from data: PhotoAssetFactoryData) -> String {
        if data.isOriginal {
            return data.originalFilename
        } else {
            return nameStrategy.makeModifiedFilename(originalFilename: data.originalFilename, filenameExtension: data.filenameExtension)
        }
    }
}
