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
import PDCore
import Foundation

public protocol ProcessedPhotoBlockDeleter {
    func deleteBlocks(for photoIdentifiers: [AnyVolumeIdentifier]) async throws
}

public final class DefaultProcessedPhotoBlockDeleter: ProcessedPhotoBlockDeleter {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func deleteBlocks(for photoIdentifiers: [AnyVolumeIdentifier]) async throws {
        Log.info("Deleting blocks for \(photoIdentifiers.count) photos.", domain: .photosTagMigration)

        guard !photoIdentifiers.isEmpty else {
            Log.debug("No identifiers provided, exiting.", domain: .photosTagMigration)
            return
        }

        do {
            try await context.perform { [context] in
                var processedCount = 0
                for identifier in photoIdentifiers {
                    guard let photo = Photo.fetch(identifier: identifier, in: context) else {
                        Log.warning("Photo not found, skipping. ID: \(identifier.id)", domain: .photosTagMigration)
                        continue
                    }

                    guard !photo.isAvailableOffline && !photo.isInheritingOfflineAvailable && !photo.isVideo else {
                        Log.debug("Skipping offline or video photo. ID: \(identifier.id)", domain: .photosTagMigration)
                        continue
                    }

                    photo.photoRevision.removeOldBlocks(in: context)
                    processedCount += 1
                }

                Log.info("Processed \(processedCount) photos, saving context.", domain: .photosTagMigration)
                try context.saveOrRollback()
            }
            Log.info("Block deletion completed successfully.", domain: .photosTagMigration)

        } catch {
            Log.warning("Failed to delete photo blocks.", domain: .photosTagMigration)
            throw error
        }
    }

}
