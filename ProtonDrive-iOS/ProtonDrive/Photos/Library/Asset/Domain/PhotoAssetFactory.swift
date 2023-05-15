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

protocol PhotoAssetFactory {
    func makeAsset(identifier: PhotoIdentifier, url: URL, hash: Data, filename: String, isOriginal: Bool) -> PhotoAsset
}

final class LocalPhotoAssetFactory: PhotoAssetFactory {
    private let nameStrategy: PhotoLibraryFilenameStrategy

    init(nameStrategy: PhotoLibraryFilenameStrategy) {
        self.nameStrategy = nameStrategy
    }

    func makeAsset(identifier: PhotoIdentifier, url: URL, hash: Data, filename: String, isOriginal: Bool) -> PhotoAsset {
        let filename = makeName(filename: filename, isOriginal: isOriginal)
        let filenameHash = "" // TODO: next MR
        return PhotoAsset(
            url: url,
            filename: filename,
            filenameHash: filenameHash,
            contentHash: hash.hexString(),
            exif: [:], // TODO: next MR
            metadata: PhotoAsset.Metadata(
                cloudIdentifier: identifier.cloudIdentifier,
                creationDate: identifier.creationDate,
                modifiedDate: identifier.modifiedDate
            )
        )
    }

    private func makeName(filename: String, isOriginal: Bool) -> String {
        if isOriginal {
            return filename
        } else {
            return nameStrategy.makeModifiedFilename(from: filename)
        }
    }
}
