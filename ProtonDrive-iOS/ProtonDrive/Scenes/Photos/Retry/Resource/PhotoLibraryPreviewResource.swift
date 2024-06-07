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
    typealias Filename = String
    
    enum Errors: Error {
        case noImageProvided(localIdentifier: Identifier)
        case requestReturned(error: NSError)
        case imageIsNotConvertibleToPng(localIdentifier: Identifier)
    }
    
    var assetsAndResourcesForIds: ([Identifier]) -> [(Identifier, AssetType, Filename?)]
    var imageForAsset: (AssetType, CGSize) async throws -> Data
    
    func execute(_ cloudIdentifiers: [Identifier], size: CGSize) async -> [AssetPreview] {
        var previews = [AssetPreview]()
        
        for (identifier, asset, filename) in assetsAndResourcesForIds(cloudIdentifiers) {
            let image: Data?
            do {
                image = try await imageForAsset(asset, size)
            } catch {
                image = .none
                Log.error("Failed to load preview image for PhotoLibraryPreviewResource: \(error)", domain: .photosUI)
            }
            
            previews.append(
                AssetPreview(
                    localIdentifier: identifier,
                    originalFilename: filename,
                    imageData: image
                )
            )
        }
        return previews
    }
    
}

extension PhotoLibraryPreviewResource where AssetType == PHAsset {
    
    static func makeApplePhotosPreviewResource() -> PhotoLibraryPreviewResource {
        let imageManager = PHImageManager.default()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeAssetSourceTypes = [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced]
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .fastFormat
        
        func buildLocalToCloudIDMapping(_ cloudIdentifiers: [String]) -> [String: String] {
            var mapping = [String: String]()
            
            PHPhotoLibrary.shared()
            .localIdentifierMappings(for: cloudIdentifiers.map(PHCloudIdentifier.init(stringValue:)))
            .forEach { cloudIdentifier, result in
                switch result {
                case let .success(localIdentifier):
                    return mapping[localIdentifier] = cloudIdentifier.stringValue
                    
                case let .failure(error):
                    Log.error("PhotoLibraryPreviewResource failed to lookup local identifier for preview: \(error)", domain: .photosUI)
                }
            }
            
            return mapping
        }
        
        return .init(
            assetsAndResourcesForIds: { cloudIdentifiers in
                let mapping = buildLocalToCloudIDMapping(cloudIdentifiers)
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(mapping.keys), options: fetchOptions)
                var collection = [(String, PHAsset, String?)]()
                
                fetchResult.enumerateObjects { asset, _, _ in
                    let resources = PHAssetResource.assetResources(for: asset)
                    collection.append((
                        mapping[asset.localIdentifier]!,
                        asset,
                        resources.first?.originalFilename
                    ))
                }
                
                return collection
            },
            imageForAsset: { asset, size in
                let (uiImage, imageResultInfo) = await imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions)
                if let requestError = imageResultInfo?[PHImageErrorKey] as? NSError {
                    throw Errors.requestReturned(error: requestError)
                }
                guard let uiImage else {
                    throw Errors.noImageProvided(localIdentifier: asset.localIdentifier)
                }
                guard let data = uiImage.pngData() else {
                    throw Errors.imageIsNotConvertibleToPng(localIdentifier: asset.localIdentifier)
                }
                return data
            }
        )
    }
    
}
