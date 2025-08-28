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

public final class DefaultPhotoTagBatchAssigner: PhotoTagBatchAssigner {
    private let tagClient: PhotoTagClient
    private let volumeID: String

    public init(tagClient: PhotoTagClient, volumeID: String) {
        self.tagClient = tagClient
        self.volumeID = volumeID
    }

    public func assignTagsAndFavorites(for batch: [AnyVolumeIdentifier: [PhotoTag]]) async throws {
        guard !batch.isEmpty else {
            Log.info("Received an empty batch, nothing to assign.", domain: .photosTagMigration)
            return
        }

        Log.info("Starting to assign tags and favorites for a batch of \(batch.count) photos.", domain: .photosTagMigration)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (identifier, tags) in batch {
                    let hasFavorite = tags.contains(.favorites)
                    let nonFavoriteTags = tags.filter { $0 != .favorites }

                    // Add task to assign regular tags if they exist
                    if !nonFavoriteTags.isEmpty {
                        group.addTask {
                            let params = AssignTagToPhotoRequest.Parameters(
                                volumeID: self.volumeID,
                                linkID: identifier.id,
                                body: .init(tags: nonFavoriteTags)
                            )
                            Log.debug("Assigning tags \(nonFavoriteTags) to photo \(identifier.id)", domain: .photosTagMigration)
                            try await self.tagClient.assignTagsToPhoto(parameters: params)
                        }
                    }

                    // Add task to assign favorite tag if it exists
                    if hasFavorite {
                        group.addTask {
                            let favParams = FavoritingPhotosParameters(
                                volumeID: self.volumeID,
                                linkID: identifier.id,
                                body: nil
                            )
                            Log.debug("Favoriting photo \(identifier.id)", domain: .photosTagMigration)
                            do {
                                // The original code used `try?` which suppresses errors.
                                // We will replicate that behavior but log the error if it occurs.
                                _ = try await self.tagClient.favoritePhoto(parameters: favParams)
                            } catch {
                                Log.warning("Failed to favorite photo \(identifier.id), but continuing with batch. Error: \(error.localizedDescription)", domain: .photosTagMigration)
                            }
                        }
                    }
                }

                // Wait for all tasks. This will throw if any of the `assignTagsToPhoto` calls failed.
                try await group.waitForAll()
            }
            Log.info("Successfully assigned tags and favorites for the batch of \(batch.count) photos.", domain: .photosTagMigration)
        } catch {
            Log.warning("Failed to assign tags for the batch.", domain: .photosTagMigration)
            // Re-throw the error to the caller
            throw error
        }
    }
}
