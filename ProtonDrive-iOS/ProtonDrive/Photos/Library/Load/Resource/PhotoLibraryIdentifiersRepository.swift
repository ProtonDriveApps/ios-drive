// Copyright (c) 2024 Proton AG
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

protocol PhotoLibraryIdentifiersRepository {
    func getIdentifiers() -> PhotoIdentifiers
}

final class ConcretePhotoLibraryIdentifiersRepository: PhotoLibraryIdentifiersRepository {
    private let mappingResource: PhotoLibraryMappingResource
    private let optionsFactory: PHFetchOptionsFactory
    private let skippableCache: PhotosSkippableCache

    init(mappingResource: PhotoLibraryMappingResource, optionsFactory: PHFetchOptionsFactory, skippableCache: PhotosSkippableCache) {
        self.mappingResource = mappingResource
        self.optionsFactory = optionsFactory
        self.skippableCache = skippableCache
    }

    func getIdentifiers() -> PhotoIdentifiers {
        let options = optionsFactory.makeOptions()
        let assetsResult = PHAsset.fetchAssets(with: options)
        var assets = [PHAsset]()
        assetsResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        let allIdentifiers = mappingResource.map(assets: assets)
        let filteredIdentifiers = allIdentifiers.filter {
            !skippableCache.isSkippable($0)
        }
        return filteredIdentifiers
    }
}
