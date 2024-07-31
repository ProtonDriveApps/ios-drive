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

final class PhotoLibraryPortraitCompoundResource: PhotoLibraryCompoundResource {
    private let plainResource: PhotoLibraryCompoundResource
    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource, plainResource: PhotoLibraryCompoundResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
        self.plainResource = plainResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        do {
            return try await executePortraitPhoto(with: identifier, asset: asset)
        } catch {
            Log.error("\(Self.self) failed to load portrait photo, falling back to plain resource", domain: .photosProcessing)
            return try await plainResource.execute(with: identifier, asset: asset)
        }
    }

    private func executePortraitPhoto(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let resources = PHAssetResource.assetResources(for: asset).filter { $0.isImage() }
        let originalFilename = try nameResource.getFilename(from: resources)

        let modifiedPhotoAssets = try await getModifiedWithFallbackToOriginal(identifier: identifier, asset: asset, resources: resources, originalFilename: originalFilename)

        return modifiedPhotoAssets.map { PhotoAssetCompound(primary: $0, secondary: []) }
    }

    private func getModifiedWithFallbackToOriginal(identifier: PhotoIdentifier, asset: PHAsset, resources: [PHAssetResource], originalFilename: String) async throws -> [PhotoAsset] {
        let adjustedResources = resources.filter({ $0.isAdjustedImage() })
        let originalResource = resources.first(where: { $0.isOriginalImage() })

        // If we do not find any adjusted image we use the original image
        if adjustedResources.isEmpty, let originalResource {
            Log.info("🏜️ No adjusted image found in Portrait Photos. CloudID: \(identifier.cloudIdentifier)", domain: .photosProcessing)
            let adjustedResource = PhotoAssetData(
                identifier: identifier,
                asset: asset,
                resource: originalResource,
                originalFilename: originalFilename,
                fileExtension: try originalResource.getNormalizedFilename().fileExtension(),
                isOriginal: true
            )
            let resource = try await assetResource.executePhoto(with: adjustedResource)
            return [resource]
        } else {
            var photoAssetData = [PhotoAssetData]()
            for resource in adjustedResources {
                photoAssetData.append(
                    PhotoAssetData(
                        identifier: identifier,
                        asset: asset,
                        resource: resource,
                        originalFilename: originalFilename,
                        fileExtension: try resource.getNormalizedFilename().fileExtension(),
                        isOriginal: false
                    )
                )
            }
            return try await photoAssetData.asyncMap {
                return try await assetResource.executePhoto(with: $0)
            }
        }
    }
}
