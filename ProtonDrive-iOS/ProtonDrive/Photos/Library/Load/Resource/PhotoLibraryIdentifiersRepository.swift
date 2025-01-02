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
import enum ProtonCoreUtilities.Either

protocol PhotoLibraryIdentifiersRepository {
    func getIdentifiers() async -> PhotoIdentifiers
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
    
    func getIdentifiers() async -> PhotoIdentifiers {
        let options = optionsFactory.makeOptions()
        let assetsResult = PHAsset.fetchAssets(with: options)
        var assets = [PHAsset]()
        assetsResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        let allIdentifiers = mappingResource.map(assets: assets)
        
        let identifiersNeedToBeUploaded = await localDuplicateCheck(allIdentifiers: allIdentifiers, assets: assets)
        return identifiersNeedToBeUploaded
    }
}

// MARK: - Duplicate check
extension ConcretePhotoLibraryIdentifiersRepository {
    func localDuplicateCheck(allIdentifiers: PhotoIdentifiers, assets: [PHAsset]) async -> PhotoIdentifiers {
        var identifiersNeedToBeUploaded: [PhotoIdentifier] = []
        var identifiersCanBeSkipped: [PhotoIdentifier: Int] = [:]
        for identifier in allIdentifiers {
            let status = skippableCache.checkSkippableStatus(identifier)
            switch status {
            case .skippable:
                continue
            case .hasPendingUpload, .newAsset:
                identifiersNeedToBeUploaded.append(identifier)
            case .needsDoubleCheck:
                guard 
                    let asset = assets.first(where: { $0.localIdentifier == identifier.localIdentifier })
                else { continue }
                let result = await doubleCheck(asset: asset, identifier: identifier)
                switch result {
                case .left(let skippableID):
                    identifiersCanBeSkipped[skippableID] = 0
                case .right(let editedID):
                    identifiersNeedToBeUploaded.append(editedID)
                }
            }
        }
        skippableCache.batchMarkAsSkippable(identifiersCanBeSkipped)

        return identifiersNeedToBeUploaded
    }

    /// Check adjustment date from Asset
    /// - Returns: Either<SkippableID, EditedID>
    private func doubleCheck(
        asset: PHAsset,
        identifier: PhotoIdentifier
    ) async -> Either<PhotoIdentifier, PhotoIdentifier> {
        let (hasAdjustmentData, adjustmentDate) = await asset.getAdjustmentDate()
        guard hasAdjustmentData else {
            // Modification date is changed by system for unknown reason
            // Given asset doesn't contain adjustment data
            return .left(identifier)
        }
        guard let adjustmentDate else {
            // Can't get adjustment date, check with BE to prevent possible data loss
            return .right(identifier)
        }
        
        // The asset modification date may change for unknown reasons.
        // The `AdjustmentDate` is the reliable date we should use.
        // If the date has been uploaded, then all changes have been synchronized.
        // Otherwise, verify with the backend to ensure consistency.
        let tmp = PhotoAssetMetadata.iOSPhotos(
            identifier: identifier.cloudIdentifier,
            modificationTime: adjustmentDate
        )
        
        let status = skippableCache.checkSkippableStatus(tmp)
        switch status {
        case .skippable:
            return .left(identifier)
        case .hasPendingUpload, .newAsset, .needsDoubleCheck:
            return .right(identifier)
        }
    }
}

private struct ComparedDataSet {
    let cachedIdentifier: PhotoAssetMetadata.iOSPhotos
    let identifier: PhotoIdentifier
}
