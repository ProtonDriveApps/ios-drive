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

public protocol PhotoTagsMigrationStateUpdater {
    func updateAnchor(lastProcessedID: String, lastProcessedCaptureTime: Date) async throws
    func markFinished(id: String) async throws
}

public final class DefaultPhotoTagsMigrationStateUpdater: PhotoTagsMigrationStateUpdater {
    private let tagsMigrationClient: TagsMigrationAPIClient
    private let localSettings: LocalSettings
    private let volumeID: String
    private let clientUID: String

    public init(tagsMigrationClient: TagsMigrationAPIClient, localSettings: LocalSettings, volumeID: String, clientUID: String) {
        self.tagsMigrationClient = tagsMigrationClient
        self.volumeID = volumeID
        self.clientUID = clientUID
        self.localSettings = localSettings
    }

    public func updateAnchor(lastProcessedID: String, lastProcessedCaptureTime: Date) async throws {
        Log.info("Updating anchor to ID: \(lastProcessedID)", domain: .photosTagMigration)
        do {
            let lastProcessedCaptureTime = Int(lastProcessedCaptureTime.timeIntervalSince1970)
            let currentTimestamp = Int(Date().timeIntervalSince1970)
            let anchor = TagsMigrationStateRequest.TagsMigrationStateAnchorRequest(lastProcessedLinkID: lastProcessedID, lastProcessedCaptureTime: lastProcessedCaptureTime, currentTimestamp: currentTimestamp, clientUID: clientUID)
            let request = TagsMigrationStateRequest(finished: false, anchor: anchor)

            try await tagsMigrationClient.setTagsMigrationState(volumeID: volumeID, request: request)
            Log.info("Anchor updated successfully.", domain: .photosTagMigration)
        } catch {
            Log.warning("Failed to update anchor.", domain: .photosTagMigration)
            throw error
        }
    }

    public func markFinished(id: String) async throws {
        Log.info("Marking migration as finished for ID: \(id)", domain: .photosTagMigration)

        do {
            let currentTimestamp = Int(Date().timeIntervalSince1970)
            let anchor = TagsMigrationStateRequest.TagsMigrationStateAnchorRequest(lastProcessedLinkID: id, lastProcessedCaptureTime: currentTimestamp, currentTimestamp: currentTimestamp, clientUID: clientUID)
            let request = TagsMigrationStateRequest(finished: true, anchor: anchor)

            try await tagsMigrationClient.setTagsMigrationState(volumeID: volumeID, request: request)
            localSettings.tagsMigrationFinished = true
            Log.info("Migration marked as finished successfully.", domain: .photosTagMigration)
        } catch {
            Log.warning("Failed to mark migration as finished.", domain: .photosTagMigration)
            throw error
        }
    }
}
