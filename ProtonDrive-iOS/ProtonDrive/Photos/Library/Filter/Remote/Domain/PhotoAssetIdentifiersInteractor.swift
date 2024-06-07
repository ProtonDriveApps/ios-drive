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

struct PhotoAssetIdentifier: Equatable, Hashable {
    let name: String
    let nameHash: String
    let url: URL
    let asset: PhotoAsset

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(nameHash)
        hasher.combine(url)
    }
}

protocol PhotoAssetIdentifiersInteractor {
    func getIdentifiers(from compound: PhotoAssetCompound) throws -> PhotosFilterItem
}

final class LocalPhotoAssetIdentifiersInteractor: PhotoAssetIdentifiersInteractor {
    private let rootDataSource: PhotosRootEncryptingFolderDataSource
    private let encryptionResource: EncryptionResource
    private let validator: NodeValidator

    init(rootDataSource: PhotosRootEncryptingFolderDataSource, encryptionResource: EncryptionResource, validator: NodeValidator) {
        self.rootDataSource = rootDataSource
        self.encryptionResource = encryptionResource
        self.validator = validator
    }

    func getIdentifiers(from compound: PhotoAssetCompound) throws -> PhotosFilterItem {
        let root = try rootDataSource.getEncryptingFolder()
        return try makeIdentifiers(from: compound, key: root.hashKey)
    }

    private func makeIdentifiers(from compound: PhotoAssetCompound, key: String) throws -> PhotosFilterItem {
        let primaryIdentifier = try makeIdentifier(from: compound.primary, key: key)
        let secondaryIdentifiers = try compound.secondary.map { try makeIdentifier(from: $0, key: key) }
        return PhotosFilterItem(primary: primaryIdentifier, secondary: secondaryIdentifiers)
    }

    private func makeIdentifier(from asset: PhotoAsset, key: String) throws -> PhotoAssetIdentifier {
        let name = asset.filename
        try validator.validateName(name)
        let nameHash = try encryptionResource.makeHmac(string: name, hashKey: key)
        return PhotoAssetIdentifier(name: name, nameHash: nameHash, url: asset.url, asset: asset)
    }
}
