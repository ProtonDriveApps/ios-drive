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

import PDClient
import PDCoreIOS
import PDCore

public final class DefaultTagsMigrationStateLoader: TagsMigrationStateLoader {
    private let tagsMigrationClient: TagsMigrationAPIClient
    private let featureFlags: FeatureFlagsControllerProtocol
    private let localSettings: LocalSettings
    private let currentClientUID: String

    public init(
        tagsMigrationClient: TagsMigrationAPIClient,
        featureFlags: FeatureFlagsControllerProtocol,
        localSettings: LocalSettings,
        currentClientUID: String
    ) {
        self.tagsMigrationClient = tagsMigrationClient
        self.featureFlags = featureFlags
        self.localSettings = localSettings
        self.currentClientUID = currentClientUID
    }

    public func loadStateIfEligible(volumeID: String) async throws -> TagsMigrationState? {

        Log.debug("Checking eligibility for tags migration.", domain: .photosTagMigration)
        guard featureFlags.hasPhotosTagsMigration else {
            Log.info("Photos tags migration feature flag is not enabled.", domain: .photosTagMigration)
            return nil
        }

        do {
            guard localSettings.tagsMigrationFinished != true else {
                Log.info("Tags migration is already finished. (local)", domain: .photosTagMigration)
                return nil
            }

            Log.debug("Loading tags migration state.", domain: .photosTagMigration)
            let state = try await tagsMigrationClient.getTagsMigrationState(volumeID: volumeID)

            guard !state.isFinished else {
                Log.info("Tags migration is already finished. (remote)", domain: .photosTagMigration)
                localSettings.tagsMigrationFinished = true
                return nil
            }

            let lastClientUID = state.anchor?.lastClientUID
            guard lastClientUID == nil || lastClientUID == currentClientUID else {
                Log.info("Another client is migrating the tags already.", domain: .albums)
                return nil
            }

            Log.info("Successfully loaded tags migration state.", domain: .photosTagMigration)
            return state
        } catch {
            Log.warning("Failed to load tags migration state", domain: .photosTagMigration)
            throw error
        }
    }

}
