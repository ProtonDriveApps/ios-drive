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

public protocol DriveUserSettingsInitializerInteractorProtocol {
    func bootstrap() async throws
}

public final class DriveUserSettingsInitializerInteractor: DriveUserSettingsInitializerInteractorProtocol {
    private let fetchUserSettingsResource: DriveUserSettingsRemoteResource
    private let localSettings: LocalSettings
    private let taskRunner: TaskRunner

    public init(
        fetchUserSettingsResource: DriveUserSettingsRemoteResource,
        localSettings: LocalSettings,
        taskRunner: TaskRunner = DefaultTaskRunner()
    ) {
        self.fetchUserSettingsResource = fetchUserSettingsResource
        self.localSettings = localSettings
        self.taskRunner = taskRunner
    }

    public func bootstrap() async throws {
        let isFirstFetch = !(localSettings.didFetchDriveUserSettings ?? false)

        if isFirstFetch {
            try await performFetchAndCache()
            localSettings.didFetchDriveUserSettings = true
        } else {
            taskRunner.runDetached { [weak self] in
                guard let self else { return }
                do {
                    try await self.performFetchAndMerge()
                } catch {
                    Log.error("Fetch user settings failed", error: error, domain: .application)
                }
            }
        }
    }

    private func performFetchAndCache() async throws {
        let response = try await fetchUserSettingsResource.fetchUserSettings()
        let userValues = response.userSettings
        let defaultValues = response.defaults

        let fullSettings = DriveUserSettings(
            layout: LayoutPreference(forcedFromValue: userValues.layout),
            sort: SortPreference(forcedFromValue: userValues.layout),
            revisionRetentionDays: userValues.revisionRetentionDays ?? defaultValues.revisionRetentionDays,
            b2bPhotosEnabled: userValues.b2BPhotosEnabled ?? defaultValues.b2BPhotosEnabled,
            docsCommentsNotificationsEnabled: userValues.docsCommentsNotificationsEnabled ?? defaultValues.docsCommentsNotificationsEnabled,
            docsCommentsNotificationsIncludeDocumentName: userValues.docsCommentsNotificationsIncludeDocumentName ?? defaultValues.docsCommentsNotificationsIncludeDocumentName,
            photoTags: userValues.photoTags ?? defaultValues.photoTags
        )

        try cacheDriveUserSettings(fullSettings)
    }

    private func performFetchAndMerge() async throws {
        let response = try await fetchUserSettingsResource.fetchUserSettings()
        let userValues = response.userSettings

        let current = getCurrentSettings()

        let merged = DriveUserSettings(
            layout: LayoutPreference(fromValue: userValues.layout) ?? current.layout,
            sort: SortPreference(fromValue: userValues.sort) ?? current.sort,
            revisionRetentionDays: userValues.revisionRetentionDays ?? current.revisionRetentionDays,
            b2bPhotosEnabled: userValues.b2BPhotosEnabled ?? current.b2bPhotosEnabled,
            docsCommentsNotificationsEnabled: userValues.docsCommentsNotificationsEnabled ?? current.docsCommentsNotificationsEnabled,
            docsCommentsNotificationsIncludeDocumentName: userValues.docsCommentsNotificationsIncludeDocumentName ?? current.docsCommentsNotificationsIncludeDocumentName,
            photoTags: userValues.photoTags ?? current.photoTags
        )

        try cacheDriveUserSettings(merged)
    }

    private func getCurrentSettings() -> DriveUserSettings {
        return DriveUserSettings(
            layout: localSettings.driveSettingsLayout,
            sort: SortPreference(forcedFromValue: localSettings.driveSettingsSort),
            revisionRetentionDays: localSettings.driveSettingsRevisionRetentionDays,
            b2bPhotosEnabled: localSettings.driveSettingsB2BPhotosEnabled,
            docsCommentsNotificationsEnabled: localSettings.driveSettingsDocsCommentsNotificationsEnabled,
            docsCommentsNotificationsIncludeDocumentName: localSettings.driveSettingsDocsCommentsNotificationsIncludeDocumentName,
            photoTags: localSettings.driveSettingsPhotoTags
        )
    }

    private func cacheDriveUserSettings(_ settings: DriveUserSettings) throws {
        localSettings.driveSettingsLayout = settings.layout
        localSettings.driveSettingsSort = settings.sort.rawValue
        localSettings.driveSettingsRevisionRetentionDays = settings.revisionRetentionDays
        localSettings.driveSettingsB2BPhotosEnabled = settings.b2bPhotosEnabled
        localSettings.driveSettingsDocsCommentsNotificationsEnabled = settings.docsCommentsNotificationsEnabled
        localSettings.driveSettingsDocsCommentsNotificationsIncludeDocumentName = settings.docsCommentsNotificationsIncludeDocumentName
        localSettings.driveSettingsPhotoTags = settings.photoTags
    }
}
