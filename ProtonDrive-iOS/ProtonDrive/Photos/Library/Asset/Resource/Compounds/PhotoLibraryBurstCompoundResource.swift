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
    struct BurstAssetResources {
        let primaryResource: PHAssetResource
        let secondaryResources: [PHAssetResource]
    }

    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let primaryResources = PHAssetResource.assetResources(for: asset)
        let secondaryResources = fetchSecondaryResources(for: asset)
        let filename = try nameResource.getPhotoFilename(from: primaryResources)
        return try await execute(identifier: identifier, primary: primaryResources, secondary: secondaryResources, filename: filename)
    }

    private func fetchSecondaryResources(for asset: PHAsset) -> [[PHAssetResource]] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAllBurstAssets = true
        let secondaryAssets = PHAsset.fetchAssets(withBurstIdentifier: asset.burstIdentifier ?? "", options: fetchOptions)
        var secondaryResources = [[PHAssetResource]]()
        secondaryAssets.enumerateObjects { secondaryAsset, _, _ in
            if secondaryAsset.localIdentifier != asset.localIdentifier {
                secondaryResources.append(PHAssetResource.assetResources(for: secondaryAsset))
            }
        }
        return secondaryResources
    }

    private func execute(identifier: PhotoIdentifier, primary: [PHAssetResource], secondary: [[PHAssetResource]], filename: String) async throws -> [PhotoAssetCompound] {
        // We need to go through all assets and group originals into one asset compound
        // And then try to group modified resources into another asset compound
        let originalResources = try getBurstResources(primary: primary, secondary: secondary, type: .photo)
        let originalCompound = try await loadBurst(with: identifier, resources: originalResources, filename: filename, isOriginal: true)

        guard let modifiedResources = try? getBurstResources(primary: primary, secondary: secondary, type: .fullSizePhoto) else {
            return [originalCompound]
        }

        let modifiedCompound = try await loadBurst(with: identifier, resources: modifiedResources, filename: filename, isOriginal: false)
        return [originalCompound, modifiedCompound]
    }

    private func getBurstResources(primary: [PHAssetResource], secondary: [[PHAssetResource]], type: PHAssetResourceType) throws -> BurstAssetResources {
        let primaryResource = try getResource(from: primary, with: type)
        let secondaryResources = secondary.compactMap { try? getResource(from: $0, with: type) }
        return BurstAssetResources(primaryResource: primaryResource, secondaryResources: secondaryResources)
    }

    private func getResource(from resources: [PHAssetResource], with type: PHAssetResourceType) throws -> PHAssetResource {
        guard let resource = resources.first(where: { $0.type == type }) else {
            throw PhotoLibraryBurstCompoundResourceError.resourceMissing
        }
        return resource
    }

    private func loadBurst(with identifier: PhotoIdentifier, resources: BurstAssetResources, filename: String, isOriginal: Bool) async throws -> PhotoAssetCompound {
        let primaryData = PhotoAssetData(identifier: identifier, resource: resources.primaryResource, filename: filename, isOriginal: isOriginal)
        let primaryAsset = try await assetResource.executePhoto(with: primaryData)
        let secondaryAssets = try await resources.secondaryResources.asyncMap {
            let data = PhotoAssetData(identifier: identifier, resource: $0, filename: filename, isOriginal: isOriginal)
            return try await assetResource.executePhoto(with: data)
        }
        return PhotoAssetCompound(primary: primaryAsset, secondary: secondaryAssets)
    }
}
