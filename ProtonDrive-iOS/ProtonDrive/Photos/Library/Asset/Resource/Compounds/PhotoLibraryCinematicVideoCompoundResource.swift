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

final class PhotoLibraryCinematicVideoCompoundResource: PhotoLibraryCompoundResource {
    private let plainResource: PhotoLibraryCompoundResource
    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource, plainResource: PhotoLibraryCompoundResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
        self.plainResource = plainResource
    }

    /// Tries to generate a cinematic video from the given asset. If it fails, it falls back to the plain resource.
    /// - Parameters:
    ///   - identifier: Identifier of the photo inside Proton Drive, contains the local identifier of the asset as well as the cloud identifier.
    ///   - asset: Object representing the photo in the Photos library.
    /// - Returns: Array of PhotoAssetCompound objects, containing the primary and secondary assets. These are representations of the photos as Proton Drive expects them.
    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        do {
            return try await executeCinematicVideo(with: identifier, asset: asset)
        } catch {
            Log.error("\(Self.self) failed to load cinematic video, falling back to plain resource", domain: .photosProcessing)
            return try await plainResource.execute(with: identifier, asset: asset)
        }
    }

    private func executeCinematicVideo(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let resources = PHAssetResource.assetResources(for: asset).filter { $0.isVideo() }
        let originalFilename = try nameResource.getFilename(from: resources)

        let modifiedPhotoAssets = try await getModifiedWithFallbackToOriginal(identifier: identifier, asset: asset, resources: resources, originalFilename: originalFilename)

        return modifiedPhotoAssets.map { PhotoAssetCompound(primary: $0, secondary: []) }
    }

    // We upload the rendered asset with the name of the unmodified asset.
    private func getModifiedWithFallbackToOriginal(identifier: PhotoIdentifier, asset: PHAsset, resources: [PHAssetResource], originalFilename: String) async throws -> [PhotoAsset] {
        let adjustedResources = resources.filter({ $0.isAdjustedVideo() })
        let originalResource = resources.first(where: { $0.isOriginalVideo() })

        // If we do not find any adjusted image we use the original video
        if adjustedResources.isEmpty, let originalResource {
            Log.info("🏜️ No adjusted image found in Cinematic Video. CloudID: \(identifier.cloudIdentifier)", domain: .photosProcessing)
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
