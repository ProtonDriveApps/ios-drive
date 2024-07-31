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
import Photos
import PDCore

final class PhotosLibraryTreeRepository: TreeRepository {
    private let optionsFactory: PHFetchOptionsFactory
    private let nameResource: PhotoLibraryNameResource
    private let filenameStrategy: PhotoLibraryFilenameStrategy

    init(optionsFactory: PHFetchOptionsFactory, nameResource: PhotoLibraryNameResource, filenameStrategy: PhotoLibraryFilenameStrategy) {
        self.optionsFactory = optionsFactory
        self.nameResource = nameResource
        self.filenameStrategy = filenameStrategy
    }

    func get() async throws -> Tree {
        Log.debug("Fetching all photos from Photos Library", domain: .diagnostics)
        let assets = getAssets()
        let items = try assets.map(makeNode)
        return Tree(root: Tree.Node(nodeTitle: "root", descendants: items))
    }

    private struct IdentifiableAsset {
        let id: String
        let asset: PHAsset
    }

    private func getAssets() -> [IdentifiableAsset] {
        let options = optionsFactory.makeOptions()
        let assetsResult = PHAsset.fetchAssets(with: options)
        var assets = [PHAsset]()
        assetsResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return map(assets: assets)
    }

    private func map(assets: [PHAsset]) -> [IdentifiableAsset] {
        let identifiers = assets.map(\.localIdentifier)
        let mapping = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: identifiers)
        return assets.map { makeAsset(from: $0, mapping: mapping) }
    }

    private func makeAsset(from asset: PHAsset, mapping: [String: Result<PHCloudIdentifier, Error>]) -> IdentifiableAsset {
        return IdentifiableAsset(
            id: getCloudIdentifier(asset: asset, mapping: mapping),
            asset: asset
        )
    }

    private func makeNode(identifiableAsset: IdentifiableAsset) throws -> Tree.Node {
        return Tree.Node(
            nodeTitle: identifiableAsset.id,
            descendants: try makePhotos(asset: identifiableAsset.asset)
        )
    }

    private func makePhotos(asset: PHAsset) throws -> [Tree.Node] {
        if let burstIdentifier = asset.burstIdentifier, asset.representsBurst {
            // For burst specific fetching of related PHAssets needs to be done
            return try makeBurstPhotos(asset: asset, burstIdentifier: burstIdentifier)
        } else {
            // For other formats, all files are already referenced from the single PHAsset
            return try makePlainPhotos(asset: asset)
        }
    }

    private func getCloudIdentifier(asset: PHAsset, mapping: [String: Result<PHCloudIdentifier, Error>]) -> String {
        switch mapping[asset.localIdentifier] {
        case let .success(identifier):
            return identifier.stringValue
        case let .failure(error):
            Log.warning("\(error)", domain: .photosProcessing)
            return "missing icloud identifier"
        default:
            Log.warning("missing icloud identifier", domain: .photosProcessing)
            return "missing icloud identifier"
        }
    }

    private func makeBurstPhotos(asset: PHAsset, burstIdentifier: String) throws -> [Tree.Node] {
        let fetchOptions = PHFetchOptions.defaultPhotosOptions()
        fetchOptions.includeAllBurstAssets = true
        let secondaryAssets = PHAsset.fetchAssets(withBurstIdentifier: burstIdentifier, options: fetchOptions)
        var secondaryResources = [[PHAssetResource]]()
        secondaryAssets.enumerateObjects { secondaryAsset, _, _ in
            if secondaryAsset.localIdentifier != asset.localIdentifier { // Skip primary asset, its resources are not secondary
                secondaryResources.append(PHAssetResource.assetResources(for: secondaryAsset))
            }
        }

        // Original photos set is grouped into one photo compound (primary + secondary)
        let originalResources = PHAssetResource.assetResources(for: asset)
        let original = Tree.Node(
            nodeTitle: try nameResource.getFilename(from: originalResources),
            descendants: try secondaryResources.map { try nameResource.getFilename(from: $0) }
        )

        // Each modification of each photo is then considered a standalone photo with no related photos
        var modifications = [Tree.Node]()
        try ([originalResources] + secondaryResources).forEach { resources in
            let modifiedResources = resources.filter { $0.type != .photo && $0.isImage() }
            guard !modifiedResources.isEmpty else { return }
            let originalName = try nameResource.getFilename(from: resources)
            modifiedResources.forEach { resource in
                let name = filenameStrategy.makeModifiedFilename(originalFilename: originalName, filenameExtension: resource.originalFilename.fileExtension())
                let photo = Tree.Node(nodeTitle: name)
                modifications.append(photo)
            }
        }

        return [original] + modifications
    }

    private func makePlainPhotos(asset: PHAsset) throws -> [Tree.Node] {
        var photos = [Tree.Node]()
        let allResources = PHAssetResource.assetResources(for: asset)
        var resources = allResources

        // Try to find original live photo pair
        if let originalPhoto = resources.first(where: { $0.isOriginalImage() }), let originalPairedVideo = resources.first(where: { $0.isOriginalPairedVideo() }) {
            let photo = Tree.Node(
                nodeTitle: try originalPhoto.getNormalizedFilename(),
                descendants: [try originalPairedVideo.getNormalizedFilename()]
            )
            photos.append(photo)
            resources = resources.filter { $0 != originalPhoto && $0 != originalPairedVideo }
        }

        // Try to find modified live photo pair
        if let modifiedPhoto = resources.first(where: { $0.isAdjustedImage() }), let modifiedPairedVideo = resources.first(where: { $0.isAdjustedPairedVideo() }) {
            let photoFilename = try nameResource.getPhotoFilename(from: allResources)
            let videoFilename = try nameResource.getPairedVideoFilename(from: allResources)
            let photo = Tree.Node(
                nodeTitle: filenameStrategy.makeModifiedFilename(originalFilename: photoFilename, filenameExtension: photoFilename.fileExtension()),
                descendants: [filenameStrategy.makeModifiedFilename(originalFilename: videoFilename, filenameExtension: modifiedPairedVideo.originalFilename.fileExtension())]
            )
            photos.append(photo)
            resources = resources.filter { $0 != modifiedPhoto && $0 != modifiedPairedVideo }
        }

        // Try to find cinematic videos
        if asset.mediaSubtypes.contains(.videoCinematic),
           let originalVideo = resources.first(where: { $0.isOriginalVideo() }) {
            let modifiedVideos = resources.filter({ $0.isAdjustedVideo() })

            let originalVideoFilename = try nameResource.getFilename(from: [originalVideo])

            if modifiedVideos.isEmpty {
                let photo = Tree.Node(nodeTitle: originalVideoFilename)
                photos.append(photo)
                return photos
            }

            try modifiedVideos.forEach { modifiedVideo in
                let modifiedVideoFilename = try nameResource.getFilename(from: [modifiedVideo])
                let videoFilename = filenameStrategy.makeModifiedFilename(originalFilename: originalVideoFilename, filenameExtension: modifiedVideoFilename.fileExtension())
                let photo = Tree.Node(nodeTitle: videoFilename)
                photos.append(photo)
            }
            return photos
        }

        // Try to find portrait photos
        if asset.mediaSubtypes.contains(.photoDepthEffect),
           let originalPhoto = resources.first(where: { $0.isOriginalImage() }) {
            let modifiedPhotos = resources.filter({ $0.isAdjustedImage() })

            let originalPhotoFilename = try nameResource.getFilename(from: [originalPhoto])

            if modifiedPhotos.isEmpty {
                let photo = Tree.Node(nodeTitle: originalPhotoFilename)
                photos.append(photo)
                return photos
            }

            try modifiedPhotos.forEach { modifiedPhoto in
                let modifiedPhotoFilename = try nameResource.getFilename(from: [modifiedPhoto])
                let photoFilename = filenameStrategy.makeModifiedFilename(originalFilename: originalPhotoFilename, filenameExtension: modifiedPhotoFilename.fileExtension())
                let photo = Tree.Node(nodeTitle: photoFilename)
                photos.append(photo)
            }
            return photos
        }

        // All other files are considered to be a standalone photos.
        let originalFilename = try nameResource.getFilename(from: allResources)
        resources.filter { $0.isImage() || $0.isVideo() }.forEach { resource in
            if resource.isOriginalImage() || resource.isOriginalVideo() {
                // If the resource represents original file, the name is retained as is
                let photo = Tree.Node(nodeTitle: originalFilename)
                photos.append(photo)
            } else {
                // Otherwise we adjust the name to distinguish the original from modification
                let name = filenameStrategy.makeModifiedFilename(originalFilename: originalFilename, filenameExtension: resource.originalFilename.fileExtension())
                let photo = Tree.Node(nodeTitle: name)
                photos.append(photo)
            }
        }

        return photos
    }
}
