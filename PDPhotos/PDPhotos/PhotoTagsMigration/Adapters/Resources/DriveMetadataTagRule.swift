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
import PDCore
import CoreData

final class DriveMetadataTagRule: PhotoTagRule {
    private let managedContext: NSManagedObjectContext

    init(managedContext: NSManagedObjectContext) {
        self.managedContext = managedContext
    }

    func apply(toPhoto identifier: AnyVolumeIdentifier, analyzeResult: MigrationAnalyzeResult) async -> MigrationAnalyzeResult {
        Log.debug("Applying DriveMetadataTagRule to identifier: \(identifier.id)", domain: .photosTagMigration)
        let context = analyzeResult.taggingContext
        guard context.control == .continue else { return analyzeResult }

        return await managedContext.perform { [weak self] in
            guard let self else {
                // This case is highly unlikely but good practice to handle.
                Log.warning("DriveMetadataTagRule was deallocated while processing \(identifier.id). Aborting.", domain: .photosTagMigration)
                return analyzeResult
                    .update(taggingContext: TaggingContext(assignedTags: context.assignedTags, control: .abort))
            }

            guard let photo = CoreDataPhoto.fetch(identifier: identifier, in: self.managedContext) else {
                Log.warning("Photo \(identifier.id) not found in CoreData. Aborting this rule.", domain: .photosTagMigration)
                return analyzeResult
                    .update(taggingContext: TaggingContext(assignedTags: context.assignedTags, control: .abort))
            }

            var updatedTags = context.assignedTags
            let initialTagCount = updatedTags.count

            // --- Phase Start ---
            Log.debug("Starting Drive Metadata analysis for \(identifier.id). Initial tags: \(context.assignedTags)", domain: .photosTagMigration)

            // Apply all rules based on CoreData properties
            self.applyFavoriteTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyScreenshotTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyVideoTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyLivePhotoTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyMotionPhotoTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applySelfieTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyPortraitTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyBurstTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyPanoramaTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)
            self.applyRawTagIfNeeded(photo: photo, tags: &updatedTags, identifier: identifier)

            // --- Phase End ---
            if updatedTags.count > initialTagCount {
                let newTags = updatedTags.subtracting(context.assignedTags)
                Log.info("Drive Metadata analysis for \(identifier.id) found new tags: \(newTags). Total tags: \(updatedTags)", domain: .photosTagMigration)
            } else {
                Log.debug("Drive Metadata analysis for \(identifier.id) found no new tags.", domain: .photosTagMigration)
            }

            // This rule always continues to the next, as it only gathers initial data.
            return analyzeResult
                .update(taggingContext: TaggingContext(assignedTags: updatedTags, control: .continue))
        }
    }

    // MARK: - Private Helpers with Logging

    private func applyFavoriteTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Cannot be inferred from drive metadata.
    }

    private func applyScreenshotTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard !tags.contains(.screenshots) else { return }
        if photo.decryptedName.lowercased().contains("screenshot") {
            Log.debug("Found 'screenshot' in filename for \(identifier.id), applying .screenshots tag.", domain: .photosTagMigration)
            tags.insert(.screenshots)
        }
    }

    private func applyVideoTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard tags.isDisjoint(with: PhotoTag.autoDetectedSystemTags) else { return }
        guard photo.isVideo else { return }
        Log.debug("Photo \(identifier.id) has isVideo property set, applying .videos tag.", domain: .photosTagMigration)
        tags.insert(.videos)
    }

    private func applyLivePhotoTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard tags.isDisjoint(with: PhotoTag.autoDetectedSystemTags) else { return }
        guard photo.canBeLivePhoto else { return }
        Log.debug("Photo \(identifier.id) has canBeLivePhoto property set, applying .livePhotos tag.", domain: .photosTagMigration)
        tags.insert(.livePhotos)
    }

    private func applyMotionPhotoTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Cannot be inferred from drive metadata.
    }

    private func applySelfieTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Cannot be inferred from drive metadata.
    }

    private func applyPortraitTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Cannot be inferred from drive metadata.
    }

    private func applyBurstTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard tags.isDisjoint(with: PhotoTag.autoDetectedSystemTags) else { return }
        guard photo.canBeBurstPhoto else { return }
        Log.debug("Photo \(identifier.id) has canBeBurstPhoto property set, applying .bursts tag.", domain: .photosTagMigration)
        tags.insert(.bursts)
    }

    private func applyPanoramaTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        // Cannot be inferred reliably from drive metadata.
    }

    private func applyRawTagIfNeeded(photo: CoreDataPhoto, tags: inout Set<PhotoTag>, identifier: AnyVolumeIdentifier) {
        guard tags.isDisjoint(with: PhotoTag.autoDetectedSystemTags) else { return }
        guard photo.isRawPhoto else { return }
        Log.debug("Photo \(identifier.id) has isRawPhoto property set, applying .raw tag.", domain: .photosTagMigration)
        tags.insert(.raw)
    }
}
