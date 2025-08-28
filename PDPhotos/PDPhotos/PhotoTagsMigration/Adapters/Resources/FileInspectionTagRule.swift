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

import CoreData
import Foundation
import PDCore
import ImageIO
import UniformTypeIdentifiers
import Combine

final class FileInspectionTagRule: PhotoTagRule {
    private let fileContentResource: FileContentResource
    private let managedContext: NSManagedObjectContext
    private let xAttrBackfillAnalyzer: XAttrBackfillAnalyzer

    init(
        fileContentResource: FileContentResource,
        managedContext: NSManagedObjectContext,
        xAttrBackfillAnalyzer: XAttrBackfillAnalyzer
    ) {
        self.fileContentResource = fileContentResource
        self.managedContext = managedContext
        self.xAttrBackfillAnalyzer = xAttrBackfillAnalyzer
    }

    func apply(toPhoto identifier: AnyVolumeIdentifier, analyzeResult: MigrationAnalyzeResult) async throws -> MigrationAnalyzeResult {
        Log.debug("Applying FileInspectionTagRule to identifier: \(identifier.id)", domain: .photosTagMigration)
        let context = analyzeResult.taggingContext
        let backfillXAttr = analyzeResult.xAttrContext.extendedAttributes

        // Videos are not compatible with any tag that can be discovered from the file exif or file XMP (e.g. favorite)
        // No need to download the entire file and check.
        guard !context.assignedTags.contains(.videos) else {
            Log.debug("Skipping file inspection for identifier \(identifier.id) as it is already tagged as a video.", domain: .photosTagMigration)
            return analyzeResult
                .update(xAttrContext: XAttrBackfillContext(extendedAttributes: backfillXAttr, control: .finished))
        }

        do {
            let content = try await downloadAndDecrypt(identifier)

            let photoURL = content.url

            defer {
                Log.debug("Cleaning up downloaded file for \(identifier.id) at path: \(photoURL.path)", domain: .photosTagMigration)
                try? FileManager.default.removeItem(at: photoURL)
            }

            try Task.checkCancellation()

            var updatedTags = context.assignedTags

            // --- Step 1: Create ImageInspector helpers ONCE ---
            guard let inspector = ImageInspector(url: photoURL) else {
                Log.warning("Failed to create ImageInspector for \(identifier.id). The file may be corrupt or not a supported image type.", domain: .photosTagMigration)
                let finishedTaggingContext = TaggingContext(assignedTags: updatedTags, control: .finished)
                let nextTaggingContext = context.control == .continue ? finishedTaggingContext : context
                return MigrationAnalyzeResult(
                    taggingContext: nextTaggingContext,
                    xAttrContext: XAttrBackfillContext(extendedAttributes: backfillXAttr, control: .finished)
                )
            }
            let xAttrContext = await extractXAttrIfNeeded(
                xAttrContext: analyzeResult.xAttrContext,
                inspector: inspector,
                identifier: identifier,
                context: managedContext
            )
            let nextTaggingContext = updateTaggingContextIfNeeded(
                context: context,
                inspector: inspector,
                updatedTags: &updatedTags,
                identifier: identifier,
                photoURL: photoURL,
                initialTagCount: updatedTags.count
            )

            return MigrationAnalyzeResult(taggingContext: nextTaggingContext, xAttrContext: xAttrContext)
        } catch let error as CancellationError {
            Log.info("Inspection cancelled.", domain: .photosTagMigration)
            throw error
        } catch {
            Log.error("FileInspectionTagRule failed for identifier \(identifier.id)", error: error, domain: .photosTagMigration)
            throw error
        }
    }

    // MARK: - Private Helpers with Logging
    private func updateTaggingContextIfNeeded(
        context: TaggingContext,
        inspector: ImageInspector,
        updatedTags: inout Set<PhotoTag>,
        identifier: AnyVolumeIdentifier,
        photoURL: URL,
        initialTagCount: Int
    ) -> TaggingContext {
        guard context.control == .continue else { return context }

        Log.debug("Phase 1 (ImageIO) for \(identifier.id). Starting with tags: \(updatedTags)", domain: .photosTagMigration)
        self.applyFavoriteTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyScreenshotTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyVideoTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyLivePhotoTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyMotionPhotoTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applySelfieTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyPortraitTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyBurstTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyPanoramaTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)
        self.applyRawTagIfNeeded(inspector: inspector, tags: &updatedTags, identifier: identifier)

        // --- Phase 2: Consolidated XMP Check ---
        Log.debug("Phase 2 (XMP) for \(identifier.id). Starting with tags: \(updatedTags)", domain: .photosTagMigration)
        let forbiddenTags: Set<PhotoTag> = [.portraits, .panoramas, .motionPhotos, .screenshots, .videos, .livePhotos, .bursts]
        guard updatedTags.isDisjoint(with: forbiddenTags) else {
            Log.debug("Skipping XMP check for \(identifier.id) as conflicting tags already exist: \(updatedTags.intersection(forbiddenTags))", domain: .photosTagMigration)
            return TaggingContext(assignedTags: updatedTags, control: .finished)
        }

        guard let xmpMetadata = XMPScanner().scan(url: photoURL) else {
            Log.debug("No XMP metadata found for \(identifier.id).", domain: .photosTagMigration)
            return TaggingContext(assignedTags: updatedTags, control: .finished)
        }

        self.checkAndroidTagsXMP(xmp: xmpMetadata, tags: &updatedTags, identifier: identifier)

        // --- Phase 3: Heuristics for panorama ---
        Log.debug("Phase 3 (Heuristics) for \(identifier.id). Starting with tags: \(updatedTags)", domain: .photosTagMigration)
        guard updatedTags.isDisjoint(with: forbiddenTags) else {
            Log.debug("Skipping heuristic check for \(identifier.id) as conflicting tags already exist.", domain: .photosTagMigration)
            return TaggingContext(assignedTags: updatedTags, control: .finished)
        }

        self.checkPanoramaHeuristics(inspector: inspector, tags: &updatedTags, identifier: identifier)

        if updatedTags.count > initialTagCount {
            Log.info("File inspection for \(identifier.id) found new tags. Final tags: \(updatedTags)", domain: .photosTagMigration)
        } else {
            Log.debug("File inspection for \(identifier.id) did not find any new tags.", domain: .photosTagMigration)
        }
        return TaggingContext(assignedTags: updatedTags, control: .finished)
    }

    private func applyFavoriteTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Cannot be inferred from file
    }

    private func applyScreenshotTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard !tags.contains(.screenshots) else { return }
        if let comment = inspector.userComment, comment.lowercased().contains("screenshot") {
            Log.debug("Found 'screenshot' in user comment for \(identifier.id), applying .screenshots tag.", domain: .photosTagMigration)
            tags.insert(.screenshots)
        }
    }

    private func applyVideoTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Should be already inferred
    }

    private func applyLivePhotoTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Should be already inferred
    }

    private func applyMotionPhotoTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard !tags.contains(.motionPhotos) else { return }
        if let motionPhoto = inspector.xmpStringValue(for: "GCamera:MotionPhoto"), motionPhoto == "1" {
            Log.debug("Found GCamera:MotionPhoto XMP tag for \(identifier.id), applying .motionPhotos tag.", domain: .photosTagMigration)
            tags.insert(.motionPhotos)
        }
    }

    private func applySelfieTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard !tags.contains(.selfies) else { return }
        if let lensModel = inspector.lensModel, lensModel.lowercased().contains("front") {
            Log.debug("Found 'front' in lens model for \(identifier.id), applying .selfies tag.", domain: .photosTagMigration)
            tags.insert(.selfies)
        }
    }
    /// https://exiftool.org/TagNames/EXIF.html
    private func applyPortraitTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard !tags.contains(.portraits) else { return }
        if let customRendered = inspector.customRendered, customRendered == 7 || customRendered == 8 {
            Log.debug("Found CustomRendered value (\(customRendered)) for \(identifier.id), applying .portraits tag.", domain: .photosTagMigration)
            tags.insert(.portraits)
        }
    }

    private func applyBurstTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Should be already inferred
    }

    /// https://exiftool.org/TagNames/EXIF.html
    private func applyPanoramaTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard !tags.contains(.panoramas) else { return }
        if let customRendered = inspector.customRendered, customRendered == 6 {
            Log.debug("Found CustomRendered value (6) for \(identifier.id), applying .panoramas tag.", domain: .photosTagMigration)
            tags.insert(.panoramas)
        }
    }

    private func applyRawTagIfNeeded(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Should be already inferred
    }

    private func checkAndroidTagsXMP(xmp: XMPMetadata, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        if xmp.isPortrait {
            Log.debug("Found Android XMP portrait tag for \(identifier.id), applying .portraits tag.", domain: .photosTagMigration)
            tags.insert(.portraits)
        }
        if xmp.isPanorama {
            Log.debug("Found Android XMP panorama tag for \(identifier.id), applying .panoramas tag.", domain: .photosTagMigration)
            tags.insert(.panoramas)
        }
        if xmp.isMotionPhoto {
            Log.debug("Found Android XMP motion photo tag for \(identifier.id), applying .motionPhotos tag.", domain: .photosTagMigration)
            tags.insert(.motionPhotos)
        }
    }

    private func checkPanoramaHeuristics(inspector: ImageInspector, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        if let ratio = inspector.aspectRatio, ratio > 2 {
            Log.debug("Aspect ratio (\(ratio)) > 2 for \(identifier.id), applying .panoramas tag via heuristics.", domain: .photosTagMigration)
            tags.insert(.panoramas)
        }
    }

    private func downloadAndDecrypt(_ identifier: AnyVolumeIdentifier) async throws -> FileContent {
        Log.debug("Starting download and decryption for \(identifier.id)...", domain: .photosTagMigration)
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            var cancellable: AnyCancellable?
            cancellable = self?.fileContentResource.result
                .first()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            Log.error("Download/decryption failed for \(identifier.id)", error: error, domain: .photosTagMigration)
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        Log.info("Successfully downloaded and decrypted file for \(identifier.id).", domain: .photosTagMigration)
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )

            self?.fileContentResource.execute(with: identifier)
        }
    }

    // MARK: Extended attributes
    private func extractXAttrIfNeeded(
        xAttrContext: XAttrBackfillContext,
        inspector: ImageInspector,
        identifier: AnyVolumeIdentifier,
        context: NSManagedObjectContext
    ) async -> XAttrBackfillContext {
        guard xAttrContext.control == .continue else { return xAttrContext }
        let photo = await context.perform { [context] in CoreDataPhoto.fetch(identifier: identifier, in: context) }
        guard let photo else { return XAttrBackfillContext(extendedAttributes: nil, control: .abort) }
        return await xAttrBackfillAnalyzer.analyzeFile(
            inspector: inspector,
            photo: photo,
            context: context
        )
    }
}
