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
    let hash: Data
    let filename: String
    let exif: PhotoAsset.Exif
    let isOriginal: Bool
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
            contentHash: data.hash.hexString(),
            exif: data.exif,
            metadata: PhotoAsset.Metadata(
                cloudIdentifier: data.identifier.cloudIdentifier,
                creationDate: data.identifier.creationDate,
                modifiedDate: data.identifier.modifiedDate
            )
        )
    }

    private func makeName(from data: PhotoAssetFactoryData) -> String {
        if data.isOriginal {
            return data.filename
        } else {
            return nameStrategy.makeModifiedFilename(from: data.filename)
        }
    }
}
