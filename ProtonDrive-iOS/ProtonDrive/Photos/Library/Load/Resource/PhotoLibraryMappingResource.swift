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

enum PhotoLibraryMappingResourceError: Error {
    case invalidAsset
}

protocol PhotoLibraryMappingResource {
    func map(assets: [PHAsset]) -> PhotoIdentifiers
}

final class LocalPhotoLibraryMappingResource: PhotoLibraryMappingResource {
    private let library = PHPhotoLibrary.shared()

    func map(assets: [PHAsset]) -> PhotoIdentifiers {
        let identifiers = assets.map(\.localIdentifier)
        let mapping = library.cloudIdentifierMappings(forLocalIdentifiers: identifiers)
        return assets.compactMap { try? makeAsset(from: $0, mapping: mapping) }
    }

    private func makeAsset(from asset: PHAsset, mapping: [String: Result<PHCloudIdentifier, Error>]) throws -> PhotoIdentifier {
        guard let result = mapping[asset.localIdentifier] else {
            throw PhotoLibraryFetchResourceError.missingMapping
        }

        return PhotoIdentifier(
            localIdentifier: asset.localIdentifier,
            cloudIdentifier: try getIdentifier(from: result),
            creationDate: asset.creationDate,
            modifiedDate: asset.modificationDate
        )
    }

    private func getIdentifier(from result: Result<PHCloudIdentifier, Error>) throws -> String {
        switch result {
        case let .success(identifier):
            return identifier.stringValue
        case let .failure(error):
            throw error
        }
    }
}
