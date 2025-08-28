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

import Foundation
import Photos
import PDCore
import CoreData

final class PhotosMetadataTagRule: PhotoTagRule {
    private let assetResource: LocalPhotoLibraryAssetResource
    private let assetDataFetcher: PhotoAssetDataFetcherResource
    private let managedContext: NSManagedObjectContext
    private let xAttrBackfillAnalyzer: XAttrBackfillAnalyzer

    init(
        assetResource: LocalPhotoLibraryAssetResource,
        assetDataFetcher: PhotoAssetDataFetcherResource,
        storageManager: StorageManager,
        xAttrBackfillAnalyzer: XAttrBackfillAnalyzer
    ) {
        self.managedContext = storageManager.photosBackgroundContext
        self.assetResource = assetResource
        self.assetDataFetcher = assetDataFetcher
        self.xAttrBackfillAnalyzer = xAttrBackfillAnalyzer
    }

    func apply(toPhoto identifier: AnyVolumeIdentifier, analyzeResult: MigrationAnalyzeResult) async throws -> MigrationAnalyzeResult {
        let context = analyzeResult.taggingContext
        do {
            Log.debug("Starting Photos Library Metadata analysis for \(identifier.id). Initial tags: \(context.assignedTags)", domain: .photosTagMigration)

            let (photo, iCloudId): (CoreDataPhoto?, PhotoAssetDataFetcherResource.iCloudId?) = await managedContext.perform { [managedContext] in
                Log.debug("Fetching CoreData photo and attributes for \(identifier.id)", domain: .photosTagMigration)
                guard let photo = CoreDataPhoto.fetch(identifier: identifier, in: managedContext) else {
                    return (nil, nil)
                }

                guard let attributes = try? photo.photoRevision.decryptedExtendedAttributes(),
                      let iCloudId = attributes.iOSPhotos?.iCloudID else {
                    Log.debug("Could not find iCloudID in extended attributes for \(identifier.id)", domain: .photosTagMigration)
                    return (photo, nil)
                }

                Log.debug("Found iCloudID \(iCloudId) for photo \(identifier.id)", domain: .photosTagMigration)
                return (photo, iCloudId)
            }

            // The photo was deleted in the meantime, we cannot proceed
            guard let photo else {
                Log.warning("Photo \(identifier.id) not found in CoreData. Aborting this rule.", domain: .photosTagMigration)
                let abortTaggingContext = TaggingContext(assignedTags: context.assignedTags, control: .abort)
                let nextTaggingContext = context.control == .continue ? abortTaggingContext : context
                return MigrationAnalyzeResult(
                    taggingContext: nextTaggingContext,
                    xAttrContext: XAttrBackfillContext(extendedAttributes: nil, control: .abort)
                )
            }

            // The photo was uploaded from another client, or we couldn't find it in our local iCloud, fallback to file inspection
            guard let iCloudId = iCloudId,
                  let assetData = await assetDataFetcher.fetchAssetData(iCloudID: iCloudId)
            else {
                Log.debug("Could not fetch asset data for photo \(identifier.id) using its iCloudID. Continuing to next rule.", domain: .photosTagMigration)
                let continueTaggingContext = TaggingContext(assignedTags: context.assignedTags, control: .continue)
                let nextTaggingContext = context.control == .continue ? continueTaggingContext : context
                return MigrationAnalyzeResult(
                    taggingContext: nextTaggingContext,
                    xAttrContext: XAttrBackfillContext(extendedAttributes: nil, control: .continue)
                )
            }

            let photoAsset = try await assetResource.executePhoto(with: assetData)
            let newTaggingContext = extractTagsIfNeeded(taggingContext: context, photoAsset: photoAsset, identifier: identifier)
            let xAttr = await extractXAttrInNeeded(
                xAttrContext: analyzeResult.xAttrContext,
                photoAsset: photoAsset,
                photo: photo
            )
            return MigrationAnalyzeResult(taggingContext: newTaggingContext, xAttrContext: xAttr)
        } catch {
            Log.error("PhotosMetadataTagRule failed for photo \(identifier.id).", error: error, domain: .photosTagMigration)
            throw error
        }
    }

    private func extractTagsIfNeeded(
        taggingContext: TaggingContext,
        photoAsset: PhotoAsset,
        identifier: AnyVolumeIdentifier
    ) -> TaggingContext {
        guard taggingContext.control == .continue else { return taggingContext }

        let newTags = extractTags(from: photoAsset)
        let combinedTags = taggingContext.assignedTags.union(newTags)

        if newTags.isEmpty {
             Log.debug("Photos Library analysis for \(identifier.id) found no new tags. Finalizing with tags: \(combinedTags).", domain: .photosTagMigration)
        } else {
             Log.info("Photos Library analysis for \(identifier.id) found new tags: \(newTags). Final tags: \(combinedTags). Analysis finished.", domain: .photosTagMigration)
        }
        return TaggingContext(assignedTags: combinedTags, control: .finished)
    }

    private func extractTags(from asset: PhotoAsset) -> Set<PhotoTag> {
        Set(asset.tags.compactMap(PhotoTag.init(rawValue:)))
    }

    private func extractXAttrInNeeded(
        xAttrContext: XAttrBackfillContext,
        photoAsset: PhotoAsset,
        photo: Photo
    ) async -> XAttrBackfillContext {
        guard xAttrContext.control == .continue else { return xAttrContext }
        return await xAttrBackfillAnalyzer.analyzeLocalAssetMetadata(
            assetMetadata: photoAsset.metadata,
            photo: photo,
            context: managedContext
        )
    }
}
