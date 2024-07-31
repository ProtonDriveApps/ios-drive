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

enum PhotoLibraryBurstCompoundResourceError: Error {
    case resourceMissing
}

final class PhotoLibraryBurstCompoundResource: PhotoLibraryCompoundResource {
    struct BurstAsset {
        let primaryResource: AssetResource
        let secondaryResources: [AssetResource]
    }

    struct AssetResource {
        let asset: PHAsset
        let resource: PHAssetResource
        let filename: String
    }

    struct AssetResources {
        let asset: PHAsset
        let resources: [PHAssetResource]
    }

    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let primaryResources = PHAssetResource.assetResources(for: asset)
        let primary = AssetResources(asset: asset, resources: primaryResources)
        let secondary = fetchSecondaryResources(for: asset)
        return try await execute(identifier: identifier, primary: primary, secondary: secondary)
    }

    private func fetchSecondaryResources(for asset: PHAsset) -> [AssetResources] {
        let fetchOptions = PHFetchOptions.defaultPhotosOptions()
        fetchOptions.includeAllBurstAssets = true
        let secondaryAssets = PHAsset.fetchAssets(withBurstIdentifier: asset.burstIdentifier ?? "", options: fetchOptions)
        var secondaryResources = [AssetResources]()
        secondaryAssets.enumerateObjects { secondaryAsset, _, _ in
            if secondaryAsset.localIdentifier != asset.localIdentifier {
                let resources = AssetResources(asset: secondaryAsset, resources: PHAssetResource.assetResources(for: secondaryAsset))
                secondaryResources.append(resources)
            }
        }
        return secondaryResources
    }

    private func execute(identifier: PhotoIdentifier, primary: AssetResources, secondary: [AssetResources]) async throws -> [PhotoAssetCompound] {
        // We need to go through all assets and group originals into one asset compound
        let originalAsset = try getOriginalBurstAsset(primary: primary, secondary: secondary)
        let originalCompound = try await loadOriginalCompound(identifier: identifier, burstAsset: originalAsset)

        // And then for each asset create standalone modified compound (if they exist)
        let modifiedResources = try getModifiedResources(from: [primary] + secondary)
        let modifiedCompounds = try await modifiedResources.asyncMap { resource in
            try await loadModifiedCompound(identifier: identifier, resource: resource)
        }

        return [originalCompound] + modifiedCompounds
    }

    private func getOriginalBurstAsset(primary: AssetResources, secondary: [AssetResources]) throws -> BurstAsset {
        let type = PHAssetResourceType.photo
        let primaryResource = try getResource(from: primary, with: type)
        let secondaryResources = secondary.compactMap { try? getResource(from: $0, with: type) }
        return BurstAsset(primaryResource: primaryResource, secondaryResources: secondaryResources)
    }

    private func getResource(from resources: AssetResources, with type: PHAssetResourceType) throws -> AssetResource {
        guard let resource = resources.resources.first(where: { $0.type == type }) else {
            throw PhotoLibraryBurstCompoundResourceError.resourceMissing
        }
        let filename = try nameResource.getFilename(from: resources.resources)
        return AssetResource(asset: resources.asset, resource: resource, filename: filename)
    }

    private func getModifiedResources(from resources: [AssetResources]) throws -> [AssetResource] {
        return try resources.flatMap {
            try getModifiedResources(from: $0)
        }
    }

    private func getModifiedResources(from resources: AssetResources) throws -> [AssetResource] {
        // Type can be PHAssetResourceType.fullSizePhoto, .adjustmentBasePhoto, ...
        let modifiedResources = resources.resources.filter({ $0.isImage() && $0.type != .photo })
        guard !modifiedResources.isEmpty else {
            return []
        }
        let filename = try nameResource.getFilename(from: resources.resources).fileName()
        return modifiedResources.map { modifiedResource in
            // Resource's filename consists of primary filename (e.g. `IMG_123`) and concrete extension (e.g. `jpg`)
            let resourceName = filename + "." + modifiedResource.originalFilename.fileExtension()
            return AssetResource(asset: resources.asset, resource: modifiedResource, filename: resourceName)
        }
    }

    private func loadOriginalCompound(identifier: PhotoIdentifier, burstAsset: BurstAsset) async throws -> PhotoAssetCompound {
        let primaryData = PhotoAssetData(identifier: identifier, asset: burstAsset.primaryResource.asset, resource: burstAsset.primaryResource.resource, originalFilename: burstAsset.primaryResource.filename, fileExtension: burstAsset.primaryResource.filename.fileExtension(), isOriginal: true)
        let primaryAsset = try await assetResource.executePhoto(with: primaryData)
        let secondaryAssets = try await burstAsset.secondaryResources.asyncMap { secondaryResource in
            let data = PhotoAssetData(identifier: identifier, asset: secondaryResource.asset, resource: secondaryResource.resource, originalFilename: secondaryResource.filename, fileExtension: secondaryResource.filename.fileExtension(), isOriginal: true)
            return try await assetResource.executePhoto(with: data)
        }
        return PhotoAssetCompound(primary: primaryAsset, secondary: secondaryAssets)
    }

    private func loadModifiedCompound(identifier: PhotoIdentifier, resource: AssetResource) async throws -> PhotoAssetCompound {
        let data = PhotoAssetData(identifier: identifier, asset: resource.asset, resource: resource.resource, originalFilename: resource.filename, fileExtension: resource.filename.fileExtension(), isOriginal: false)
        let asset = try await assetResource.executePhoto(with: data)
        return PhotoAssetCompound(primary: asset, secondary: [])
    }
}
