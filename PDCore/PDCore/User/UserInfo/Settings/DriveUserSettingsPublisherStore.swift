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
import Combine

final class DriveUserSettingsPublisherStore: ObservableObject {
    @Published private(set) var settings: DriveUserSettings
    private let scheduler: AnySchedulerOf<DispatchQueue>

    private var cancellables = Set<AnyCancellable>()

    init(localSettings: LocalSettings, scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.main.eraseToAnyScheduler()) {
        self.settings = Self.readFrom(localSettings)
        self.scheduler = scheduler

        let partial1 = Publishers.CombineLatest3(
            localSettings.publisher(for: \.driveSettingsLayout),
            localSettings.publisher(for: \.driveSettingsSort),
            localSettings.publisher(for: \.driveSettingsRevisionRetentionDays)
        )

        let partial2 = Publishers.CombineLatest3(
            localSettings.publisher(for: \.driveSettingsB2BPhotosEnabled),
            localSettings.publisher(for: \.driveSettingsDocsCommentsNotificationsEnabled),
            localSettings.publisher(for: \.driveSettingsDocsCommentsNotificationsIncludeDocumentName)
        )

        let allCombined = Publishers.CombineLatest(partial1, partial2)
            .combineLatest(localSettings.publisher(for: \.driveSettingsPhotoTags))
            .map { partials, tags in
                let ((layout, sort, retention), (b2b, notifEnabled, includeName)) = partials
                return DriveUserSettings(
                    layout: layout,
                    sort: SortPreference(forcedFromValue: sort),
                    revisionRetentionDays: retention,
                    b2bPhotosEnabled: b2b,
                    docsCommentsNotificationsEnabled: notifEnabled,
                    docsCommentsNotificationsIncludeDocumentName: includeName,
                    photoTags: tags
                )
            }

        allCombined
            .removeDuplicates()
            .receive(on: scheduler)
            .sink { [weak self] in self?.settings = $0 }
            .store(in: &cancellables)
    }

    private static func readFrom(_ localSettings: LocalSettings) -> DriveUserSettings {
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
}
