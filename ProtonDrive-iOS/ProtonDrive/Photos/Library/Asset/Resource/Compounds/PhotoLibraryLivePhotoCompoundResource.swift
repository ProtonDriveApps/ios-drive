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

enum PhotoLibraryLivePhotoFilesResourceError: Error {
    case invalidResources
}

final class PhotoLibraryLivePhotoCompoundResource: PhotoLibraryCompoundResource {
    struct LivePhotoAssetResourcePair {
        let photo: PHAssetResource
        let photoFilename: String
        let video: PHAssetResource
        let videoFilename: String
    }

    private let assetResource: PhotoLibraryAssetResource
    private let nameResource: PhotoLibraryNameResource

    init(assetResource: PhotoLibraryAssetResource, nameResource: PhotoLibraryNameResource) {
        self.assetResource = assetResource
        self.nameResource = nameResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        let resources = PHAssetResource.assetResources(for: asset)
        let originalPair = try getOriginalPair(from: resources)
        let originalCompound = try await loadLivePair(with: identifier, resources: originalPair, isOriginal: true)
        if let modifiedPair = try? getModifiedPair(from: resources) {
            let modifiedCompound = try await loadLivePair(with: identifier, resources: modifiedPair, isOriginal: false)
            return [originalCompound, modifiedCompound]
        } else {
            return [originalCompound]
        }
    }

    private func getOriginalPair(from resources: [PHAssetResource]) throws -> LivePhotoAssetResourcePair {
        guard let photoResource = resources.first(where: { $0.isOriginalImage() }) else {
            throw PhotoLibraryLivePhotoFilesResourceError.invalidResources
        }

        guard let videoResource = resources.first(where: { $0.isOriginalPairedVideo() }) else {
            throw PhotoLibraryLivePhotoFilesResourceError.invalidResources
        }

        return LivePhotoAssetResourcePair(photo: photoResource, photoFilename: photoResource.originalFilename, video: videoResource, videoFilename: videoResource.originalFilename)
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

    private func loadLivePair(with identifier: PhotoIdentifier, resources: LivePhotoAssetResourcePair, isOriginal: Bool) async throws -> PhotoAssetCompound {
        let photoData = PhotoAssetData(identifier: identifier, resource: resources.photo, filename: resources.photoFilename, isOriginal: isOriginal)
        let videoData = PhotoAssetData(identifier: identifier, resource: resources.video, filename: resources.videoFilename, isOriginal: isOriginal)
        let photoAsset = try await assetResource.executePhoto(with: photoData)
        let videoAsset = try await assetResource.executeVideo(with: videoData)
        return PhotoAssetCompound(primary: photoAsset, secondary: [videoAsset])
    }
}
