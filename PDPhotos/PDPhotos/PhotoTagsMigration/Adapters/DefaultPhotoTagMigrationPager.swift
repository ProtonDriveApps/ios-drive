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
import PDClient

final class DefaultPhotoTagMigrationPager: PhotoTagMigrationPager {
    private let listingDataSource: PhotosListingDataSource
    private let metadataRepository: RemoteMetadataFetchRepositoryProtocol
    private let volumeID: String
    private let pageSize: Int

    init(
        listingDataSource: PhotosListingDataSource,
        metadataRepository: RemoteMetadataFetchRepositoryProtocol,
        volumeID: String,
        pageSize: Int = 10
    ) {
        self.listingDataSource = listingDataSource
        self.metadataRepository = metadataRepository
        self.volumeID = volumeID
        self.pageSize = pageSize
    }

    func nextBatch(from anchor: TagsMigrationState.Anchor?) async throws -> [TaggablePhotoIdentifier] {
        Log.debug("Requesting next batch for tag migration. Anchor: \(String(describing: anchor?.lastProcessedLinkID))", domain: .photosTagMigration)

        do {
            let request = PhotosListRequestParameters(volumeId: volumeID, lastId: anchor?.lastProcessedLinkID, pageSize: pageSize, tag: nil)

            let response = try await listingDataSource.getPhotosList(with: request)
            Log.debug("Received \(response.photos.count) photos from the listing data source.", domain: .photosTagMigration)

            // Map raw photos into AnyVolumeIdentifier + captureTime
            let photos: [TaggablePhotoIdentifier] = response.photos.map { photo in
                let identifier = AnyVolumeIdentifier(id: photo.linkID, volumeID: volumeID)
                let captureDate = Date(timeIntervalSince1970: TimeInterval(photo.captureTime))
                return TaggablePhotoIdentifier(identifier: identifier, captureTime: captureDate)
            }

            let identifiers = photos.map { $0.identifier }

            if identifiers.isEmpty {
                Log.debug("No new photos in this batch to process.", domain: .photosTagMigration)
            } else {
                Log.debug("Fetching metadata for \(identifiers.count) photos.", domain: .photosTagMigration)
                _ = try await metadataRepository.fetch(identifiers: identifiers)
                Log.debug("Successfully fetched metadata.", domain: .photosTagMigration)
            }

            Log.info("Successfully prepared a batch of \(photos.count) photos for tag migration.", domain: .photosTagMigration)
            return photos
        } catch {
            Log.warning("Failed to get or process the next batch for photo tag migration.", domain: .photosTagMigration)
            throw error
        }
    }
}

public struct TaggablePhotoIdentifier: Equatable {
    public let identifier: AnyVolumeIdentifier
    public let captureTime: Date

    public init(identifier: AnyVolumeIdentifier, captureTime: Date) {
        self.identifier = identifier
        self.captureTime = captureTime
    }
}
