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

import Foundation
import UIKit
import Photos
import PDCore

protocol PhotoLibraryPreviewResourceProtocol {
    typealias Identifier = String
    func execute(_ cloudIdentifiers: [Identifier], size: CGSize) async -> [AssetPreview]
}

typealias ConcretePhotoLibraryPreviewResource = PhotoLibraryPreviewResource<PHAsset>

struct PhotoLibraryPreviewResource<AssetType>: PhotoLibraryPreviewResourceProtocol {
    enum Errors: Error {
        case noImageProvided(localIdentifier: Identifier)
        case inCloudButUnavailable(localIdentifier: Identifier)
        case cancelled(localIdentifier: Identifier)
        case degradedOnly(localIdentifier: Identifier)
        case requestReturned(error: NSError)
        case imageIsNotConvertibleToPng(localIdentifier: Identifier)
    }

    struct AssetInfo {
        let localIdentifier: String
        let cloudIdentifier: String?
        let asset: AssetType
        let filename: String?
        let creationDate: Date?
        let modificationDate: Date?
    }

    var assetsAndResourcesForIds: ([Identifier]) -> [AssetInfo]
    var imageForAsset: (AssetType, CGSize) async throws -> Data
    
    func execute(_ cloudIdentifiers: [Identifier], size: CGSize) async -> [AssetPreview] {
        var previews = [AssetPreview]()
        
        for info in assetsAndResourcesForIds(cloudIdentifiers) {
            let image: Data?
            do {
                image = try await imageForAsset(info.asset, size)
            } catch {
                image = .none
                Log.error("Failed to load preview image for PhotoLibraryPreviewResource", error: error, domain: .photosUI)
            }

            previews.append(
                AssetPreview(
                    localIdentifier: info.localIdentifier,
                    cloudIdentifier: info.cloudIdentifier,
                    originalFilename: info.filename,
                    creationDate: info.creationDate,
                    imageData: image,
                    modificationDate: info.modificationDate
                )
            )
        }
        return previews
    }
    
}

extension PhotoLibraryPreviewResource where AssetType == PHAsset {
    
    static func makeApplePhotosPreviewResource() -> PhotoLibraryPreviewResource {
        let imageManager = PHImageManager.default()
        
        let fetchOptions = PHFetchOptions.defaultPhotosOptions()
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true

        func buildLocalToCloudIDMapping(_ cloudIdentifiers: [String]) -> [String: String] {
            var mapping = [String: String]()
            
            PHPhotoLibrary.shared()
            .localIdentifierMappings(for: cloudIdentifiers.map(PHCloudIdentifier.init(stringValue:)))
            .forEach { cloudIdentifier, result in
                switch result {
                case let .success(localIdentifier):
                    return mapping[localIdentifier] = cloudIdentifier.stringValue
                    
                case let .failure(error):
                    Log.error("PhotoLibraryPreviewResource failed to lookup local identifier for preview", error: error, domain: .photosUI)
                }
            }
            
            return mapping
        }
        
        return .init(
            assetsAndResourcesForIds: { cloudIdentifiers in
                let mapping = buildLocalToCloudIDMapping(cloudIdentifiers)
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(mapping.keys), options: fetchOptions)
                var collection = [AssetInfo]()

                fetchResult.enumerateObjects { asset, _, _ in
                    let resources = PHAssetResource.assetResources(for: asset)
                    collection.append(
                        AssetInfo(
                            localIdentifier: asset.localIdentifier,
                            cloudIdentifier: mapping[asset.localIdentifier],
                            asset: asset,
                            filename: resources.first?.originalFilename,
                            creationDate: asset.creationDate,
                            modificationDate: asset.modificationDate
                        )
                    )
                }
                
                return collection
            },
            imageForAsset: { asset, size in
                let (uiImage, imageResultInfo) = await imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions)
                if let requestError = imageResultInfo?[PHImageErrorKey] as? NSError {
                    throw Errors.requestReturned(error: requestError)
                }
                guard let uiImage else {
                    throw Self.classifyMissingImage(asset: asset, info: imageResultInfo, targetSize: size)
                }
                guard let data = uiImage.pngData() else {
                    throw Errors.imageIsNotConvertibleToPng(localIdentifier: asset.localIdentifier)
                }
                return data
            }
        )
    }

    private static func classifyMissingImage(asset: PHAsset, info: [AnyHashable: Any]?, targetSize: CGSize) -> Errors {
        let isInCloud = (info?[PHImageResultIsInCloudKey] as? NSNumber)?.boolValue == true
        let isCancelled = (info?[PHImageCancelledKey] as? NSNumber)?.boolValue == true
        let isDegraded = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue == true

        let fingerprint = assetFingerprint(asset, targetSize: targetSize, info: info)
        Log.warning(
            "PhotoLibraryPreviewResource got nil UIImage. \(fingerprint)",
            domain: .photosUI
        )

        if isInCloud {
            return .inCloudButUnavailable(localIdentifier: asset.localIdentifier)
        }
        if isCancelled {
            return .cancelled(localIdentifier: asset.localIdentifier)
        }
        if isDegraded {
            return .degradedOnly(localIdentifier: asset.localIdentifier)
        }
        return .noImageProvided(localIdentifier: asset.localIdentifier)
    }

    private static func assetFingerprint(_ asset: PHAsset, targetSize: CGSize, info: [AnyHashable: Any]?) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
            .map { "\($0.type.rawValue):\($0.uniformTypeIdentifier)" }
            .joined(separator: ",")

        let infoFlags: [String] = [
            (info?[PHImageResultIsInCloudKey] as? NSNumber)?.boolValue == true ? "inCloud" : nil,
            (info?[PHImageCancelledKey] as? NSNumber)?.boolValue == true ? "cancelled" : nil,
            (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue == true ? "degraded" : nil,
        ].compactMap { $0 }
        let infoFlagsDescription = infoFlags.isEmpty ? "none" : infoFlags.joined(separator: "|")

        return [
            "localId=\(asset.localIdentifier)",
            "mediaType=\(asset.mediaType.rawValue)",
            "mediaSubtypes=\(asset.mediaSubtypes.rawValue)",
            "sourceType=\(asset.sourceType.rawValue)",
            "pixelSize=\(asset.pixelWidth)x\(asset.pixelHeight)",
            "targetSize=\(Int(targetSize.width))x\(Int(targetSize.height))",
            "burstId=\(asset.burstIdentifier ?? "nil")",
            "representsBurst=\(asset.representsBurst)",
            "resources=[\(resources)]",
            "infoFlags=\(infoFlagsDescription)"
        ].joined(separator: " ")
    }

}
