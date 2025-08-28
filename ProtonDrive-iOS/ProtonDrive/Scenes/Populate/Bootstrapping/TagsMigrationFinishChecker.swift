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
import PDClient
import PDCore
import PDCoreIOS
import Combine
import CoreData
import PDPhotos

public final class TagsMigrationFinishChecker: AppBootstrapper {
    public typealias BootstrapClient = TagsMigrationAPIClient & PhotosListingDataSource & TagsMigrationAPIClient
    private let storageManager: StorageManager
    private let client: BootstrapClient
    private let localSettings: LocalSettings
    private let featureFlags: FeatureFlagsControllerProtocol
    private let clientUIDProvider: UploadClientUIDProvider

    public init(
        storageManager: StorageManager,
        client: BootstrapClient,
        localSettings: LocalSettings,
        featureFlags: FeatureFlagsControllerProtocol,
        clientUIDProvider: UploadClientUIDProvider
    ) {
        self.storageManager = storageManager
        self.client = client
        self.localSettings = localSettings
        self.featureFlags = featureFlags
        self.clientUIDProvider = clientUIDProvider
    }

    public func bootstrap() async throws {
        Log.info("Will fetch photos tag migration state on bootstrap.", domain: .photosTagMigration)
        guard featureFlags.hasPhotosTagsMigration, localSettings.tagsMigrationFinished != true else {
            return
        }

        guard let volumeID = storageManager.getPhotosVolumeId(in: storageManager.backgroundContext) else {
            Log.info("TagsMigrationFinishChecker: No photo volume found.", domain: .photosTagMigration)
            return
        }

        do {
            let state = try await client.getTagsMigrationState(volumeID: volumeID)

            if state.isFinished {
                localSettings.tagsMigrationFinished = true
                Log.debug("Migration is finished and marked locally.", domain: .photosTagMigration)
            } else {
                let hasBackedUpPhotos = try await hasBackedUpPhotos(volumeID: volumeID)
                if hasBackedUpPhotos {
                    Log.info("TagsMigrationFinishChecker: Migration not finished.", domain: .photosTagMigration)
                } else {
                    if let rootID = storageManager.getPhotoStreamRootFolderId(in: storageManager.backgroundContext) {
                        try await markStateFinished(volumeID: volumeID, rootID: rootID.id)
                        Log.debug("Empty photo volume, mark it finished", domain: .photosTagMigration)
                    } else {
                        localSettings.tagsMigrationFinished = true
                        Log.debug("Empty photo volume, migration is finished and marked locally.", domain: .photosTagMigration)
                    }
                }
            }
        } catch {
            Log.warning("Failed to fetch migration state: \(error).", domain: .photosTagMigration)
        }
    }

    private func hasBackedUpPhotos(volumeID: String) async throws -> Bool {
        let request = PhotosListRequestParameters(volumeId: volumeID, lastId: nil, pageSize: 1, tag: nil)
        let response = try await client.getPhotosList(with: request)
        return !response.photos.isEmpty
    }

    private func markStateFinished(volumeID: String, rootID: String) async throws {
        let stateUpdater = DefaultPhotoTagsMigrationStateUpdater(
            tagsMigrationClient: client,
            localSettings: localSettings,
            volumeID: volumeID,
            clientUID: clientUIDProvider.getUploadClientUID()
        )
        try await stateUpdater.markFinished(id: rootID)
    }
}
