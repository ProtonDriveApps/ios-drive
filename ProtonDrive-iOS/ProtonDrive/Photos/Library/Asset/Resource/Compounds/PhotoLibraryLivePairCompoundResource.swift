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

struct LivePhotoAssetResourcePair {
    let photo: PHAssetResource
    let photoFilename: String
    let video: PHAssetResource
    let videoFilename: String
}

protocol PhotoLibraryLivePairCompoundResource {
    func getOriginal(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> PhotoAssetCompound
    func getModified(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> PhotoAssetCompound
}

final class ConcretePhotoLibraryLivePairCompoundResource: PhotoLibraryLivePairCompoundResource {
    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func getOriginal(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> PhotoAssetCompound {
        let resources = PHAssetResource.assetResources(for: asset)
        let originalPair = try getOriginalPair(from: resources)
        return try await loadLivePair(identifier: identifier, asset: asset, resources: originalPair, isOriginal: true)
    }

    func getModified(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> PhotoAssetCompound {
        let resources = PHAssetResource.assetResources(for: asset)
        let originalPair = try getModifiedPair(from: resources)
        return try await loadLivePair(identifier: identifier, asset: asset, resources: originalPair, isOriginal: false)
    }

    private func getOriginalPair(from resources: [PHAssetResource]) throws -> LivePhotoAssetResourcePair {
        guard let photoResource = resources.first(where: { $0.isOriginalImage() }) else {
            throw PhotoLibraryLivePhotoFilesResourceError.invalidResources
        }

        guard let videoResource = resources.first(where: { $0.isOriginalPairedVideo() }) else {
            throw PhotoLibraryLivePhotoFilesResourceError.invalidResources
        }

        return LivePhotoAssetResourcePair(
            photo: photoResource,
            photoFilename: try photoResource.getNormalizedFilename(),
            video: videoResource,
            videoFilename: try videoResource.getNormalizedFilename()
        )
    }

    private func getModifiedPair(from resources: [PHAssetResource]) throws -> LivePhotoAssetResourcePair {
        guard let photoResource = resources.first(where: { $0.isAdjustedImage() }) else {
            throw PhotoLibraryLivePhotoFilesResourceError.invalidResources
        }

        guard let videoResource = resources.first(where: { $0.isAdjustedPairedVideo() }) else {
            throw PhotoLibraryLivePhotoFilesResourceError.invalidResources
        }

        let photoFilename = try nameResource.getPhotoFilename(from: resources)
        let videoFilename = try nameResource.getPairedVideoFilename(from: resources)
        return LivePhotoAssetResourcePair(photo: photoResource, photoFilename: photoFilename, video: videoResource, videoFilename: videoFilename)
    }

    private func loadLivePair(identifier: PhotoIdentifier, asset: PHAsset, resources: LivePhotoAssetResourcePair, isOriginal: Bool) async throws -> PhotoAssetCompound {
        let photoData = PhotoAssetData(identifier: identifier, asset: asset, resource: resources.photo, originalFilename: resources.photoFilename, fileExtension: resources.photoFilename.fileExtension(), isOriginal: isOriginal)
        let videoData = PhotoAssetData(identifier: identifier, asset: asset, resource: resources.video, originalFilename: resources.videoFilename, fileExtension: resources.videoFilename.fileExtension(), isOriginal: isOriginal)
        let photoAsset = try await assetResource.executePhoto(with: photoData)
        let videoAsset = try await assetResource.executeVideo(with: videoData)
        return PhotoAssetCompound(primary: photoAsset, secondary: [videoAsset])
    }
}
