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
import PDPhotos

final class PhotoLibraryPlainCompoundResource: PhotoLibraryCompoundResource {
    private let livePhotoResource: PhotoLibraryCompoundResource
    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(livePhotoResource: PhotoLibraryCompoundResource, assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.livePhotoResource = livePhotoResource
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        // PHAsset can contain live photo.
        do {
            // If it does, we make live compounds and then compound for all other resources.
            let compounds = try await executeLiveBasedPhoto(with: identifier, asset: asset)
            Log.info("Load live photo asset \(identifier.localIdentifier)", domain: .photosProcessing)
            return compounds
        } catch {
            // If it doesn't, we fall back to retrieving plain files.
            Log.info("Load plain asset \(identifier.cloudIdentifier)", domain: .photosProcessing)
            return try await executePlainPhoto(with: identifier, asset: asset)
        }
    }

    private func executeLiveBasedPhoto(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let liveCompounds = try await livePhotoResource.execute(with: identifier, asset: asset)
        let otherResources = getOtherResources(asset)
        let otherCompounds = try await getAssets(identifier: identifier, asset: asset, resources: otherResources)
        return liveCompounds + otherCompounds
    }

    private func executePlainPhoto(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let resources = getAllValidResources(asset)
        return try await getAssets(identifier: identifier, asset: asset, resources: resources)
    }

    private func getAssets(identifier: PhotoIdentifier, asset: PHAsset, resources: [PHAssetResource]) async throws -> [PhotoAssetCompound] {
        let allResources = PHAssetResource.assetResources(for: asset)
        let originalFilename = try nameResource.getFilename(from: allResources)
        var primaryAsset: PhotoAsset?
        return try await resources.asyncMap {
            let asset = try await loadAsset(
                identifier: identifier,
                asset: asset,
                resource: $0,
                originalFilename: originalFilename,
                filename: try $0.getNormalizedFilename(),
                primaryAsset: primaryAsset
            )
            primaryAsset = asset.primary
            return asset
        }
    }

    private func getOtherResources(_ asset: PHAsset) -> [PHAssetResource] {
        let allResources = PHAssetResource.assetResources(for: asset)
        return allResources.filter { resource in
            (resource.isImage() || resource.isVideo()) && !resource.isPartOfLivePhoto()
        }
    }

    private func getAllValidResources(_ asset: PHAsset) -> [PHAssetResource] {
        let allResources = PHAssetResource.assetResources(for: asset)
        return allResources.filter { resource in
            resource.isImage() || resource.isVideo()
        }
    }

    private func loadAsset(identifier: PhotoIdentifier, asset: PHAsset, resource: PHAssetResource, originalFilename: String, filename: String, primaryAsset: PhotoAsset?) async throws -> PhotoAssetCompound {
        let isOriginal = resource.isOriginalImage() || resource.isOriginalVideo()
        let data = PhotoAssetData(identifier: identifier, asset: asset, resource: resource, originalFilename: originalFilename, fileExtension: filename.fileExtension, isOriginal: isOriginal)
        do {
            let asset = try await loadAsset(with: data, isVideo: resource.isVideo(), appendedAssetData: nil)
            return PhotoAssetCompound(primary: asset, secondary: [])
        } catch {
            // Some video files can fail when reading `readAvAsset`. We're suspecting corrupted live photo assets.
            // In such case, let's retry with preset metadata. In any case those metadata (location & camera should not differ anyway)
            if let primaryAsset {
                Log.error("Failed to load video asset data. Fallbacking to using primary asset's exif.", domain: .photosProcessing, context: LogContext([error.localizedDescription, "asset.mediaSubtypes: \(asset.mediaSubtypes.rawValue)"]))
                let appendedMetadata = AppendedAssetData(cameraInfo: primaryAsset.metadata.camera, location: primaryAsset.metadata.location)
                let asset = try await loadAsset(with: data, isVideo: resource.isVideo(), appendedAssetData: appendedMetadata)
                return PhotoAssetCompound(primary: asset, secondary: [])
            }
            throw error
        }
    }

    /// `appendedAssetData` contains main item's metadata, and is used when reading av asset fails with weird issue.
    private func loadAsset(with data: PhotoAssetData, isVideo: Bool, appendedAssetData: AppendedAssetData?) async throws -> PhotoAsset {
        if isVideo {
            return try await assetResource.executeVideo(with: data, appendedAssetData: appendedAssetData)
        } else {
            return try await assetResource.executePhoto(with: data)
        }
    }
}
