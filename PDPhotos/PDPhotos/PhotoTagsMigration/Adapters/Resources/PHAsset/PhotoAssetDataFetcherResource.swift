// Copyright (c) 2025 Proton AG
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
import Foundation
import PDCore

protocol PhotoAssetDataFetcherResource {
    typealias iCloudId = String

    func fetchAssetData(iCloudID: iCloudId) async -> PhotoAssetData?
}

final class DefaultPhotoAssetDataFetcherResource: PhotoAssetDataFetcherResource {
    private let photoIdentifierInquirer: PhotoIdentifierInquirer

    init(photoIdentifierInquirer: PhotoIdentifierInquirer) {
        self.photoIdentifierInquirer = photoIdentifierInquirer
    }

    func fetchAssetData(iCloudID: String) async -> PhotoAssetData? {
        guard let localIdentifier = photoIdentifierInquirer.localIdentifier(forCloudIdentifier: iCloudID) else {
            Log.info("Could not find local identifier for iCloud", domain: .photosTagMigration)
            return nil
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        guard let resource = getCorrectResource(asset: asset) else {
            return nil
        }

        let identifier = PhotoIdentifier(
            localIdentifier: asset.localIdentifier,
            cloudIdentifier: iCloudID,
            modifiedDate: asset.modificationDate,
            type: getType(from: asset)
        )

        return PhotoAssetData(
            identifier: identifier,
            asset: asset,
            resource: resource,
            originalFilename: resource.originalFilename,
            fileExtension: URL(fileURLWithPath: resource.originalFilename).pathExtension,
            isOriginal: true
        )
    }

    private func getCorrectResource(asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        let anyValidResource = resources.first(where: { resource in resource.isImage() || resource.isVideo() })

        // To account for portrait where we prioritize modified asset. See `PhotoLibraryPortraitCompoundResource`
        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            return resources.first(where: { $0.isAdjustedImage() }) ?? anyValidResource
        } else {
            return anyValidResource
        }
    }

    private func getType(from asset: PHAsset) -> PhotoIdentifier.IdentifierType {
        let isSmallAsset = asset.mediaType == .image && !asset.representsBurst && asset.burstIdentifier == nil
        return isSmallAsset ? .small : .big
    }
}
