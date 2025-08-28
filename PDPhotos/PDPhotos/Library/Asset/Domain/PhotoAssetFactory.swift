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

public struct PhotoAssetFactoryData {
    public  let identifier: PhotoIdentifier
    public  let url: URL
    public  let mimeType: MimeType
    public  let originalFilename: String
    public  let filenameExtension: String
    public  let width: Int
    public  let height: Int
    public  let exif: PhotoAsset.Exif
    public  let isOriginal: Bool
    public  let duration: Double?
    public  let camera: PhotoAssetMetadata.Camera
    public  let location: PhotoAssetMetadata.Location?
    public  let tags: [PhotoTag]

    public init(identifier: PhotoIdentifier, url: URL, mimeType: MimeType, originalFilename: String, filenameExtension: String, width: Int, height: Int, exif: PhotoAsset.Exif, isOriginal: Bool, duration: Double?, camera: PhotoAssetMetadata.Camera, location: PhotoAssetMetadata.Location?, tags: [PhotoTag]) {
        self.identifier = identifier
        self.url = url
        self.mimeType = mimeType
        self.originalFilename = originalFilename
        self.filenameExtension = filenameExtension
        self.width = width
        self.height = height
        self.exif = exif
        self.isOriginal = isOriginal
        self.duration = duration
        self.camera = camera
        self.location = location
        self.tags = tags
    }
}

public protocol PhotoAssetFactory {
    func makeAsset(from data: PhotoAssetFactoryData) throws -> PhotoAsset
}

public final class LocalPhotoAssetFactory: PhotoAssetFactory {
    private let nameStrategy: PhotoLibraryFilenameStrategy

    public init(nameStrategy: PhotoLibraryFilenameStrategy) {
        self.nameStrategy = nameStrategy
    }

    public func makeAsset(from data: PhotoAssetFactoryData) throws -> PhotoAsset {
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
            ),
            tags: data.tags.compactMap { $0.rawValue }
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
