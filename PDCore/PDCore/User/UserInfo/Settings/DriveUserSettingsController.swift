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

public protocol DriveUserSettingsControllerProtocol {
    var driveUserSettingsPublisher: AnyPublisher<DriveUserSettings, Never> { get }
}

public final class DriveUserSettingsController: DriveUserSettingsControllerProtocol {
    private let subject: CurrentValueSubject<DriveUserSettings, Never>
    private let scheduler: AnySchedulerOf<DispatchQueue>
    private var cancellables = Set<AnyCancellable>()

    public var driveUserSettingsPublisher: AnyPublisher<DriveUserSettings, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(localSettings: LocalSettings, scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.main.eraseToAnyScheduler()) {
        self.scheduler = scheduler
        let initial = DriveUserSettings(
            layout: localSettings.driveSettingsLayout,
            sort: SortPreference(forcedFromValue: localSettings.driveSettingsSort),
            revisionRetentionDays: localSettings.driveSettingsRevisionRetentionDays,
            b2bPhotosEnabled: localSettings.driveSettingsB2BPhotosEnabled,
            docsCommentsNotificationsEnabled: localSettings.driveSettingsDocsCommentsNotificationsEnabled,
            docsCommentsNotificationsIncludeDocumentName: localSettings.driveSettingsDocsCommentsNotificationsIncludeDocumentName,
            photoTags: localSettings.driveSettingsPhotoTags
        )

        self.subject = CurrentValueSubject(initial)

        let partial1 = Publishers.CombineLatest3(
            localSettings.publisher(for: \.driveSettingsLayout).removeDuplicates(),
            localSettings.publisher(for: \.driveSettingsSort).removeDuplicates(),
            localSettings.publisher(for: \.driveSettingsRevisionRetentionDays).removeDuplicates()
        )

        let partial2 = Publishers.CombineLatest3(
            localSettings.publisher(for: \.driveSettingsB2BPhotosEnabled).removeDuplicates(),
            localSettings.publisher(for: \.driveSettingsDocsCommentsNotificationsEnabled).removeDuplicates(),
            localSettings.publisher(for: \.driveSettingsDocsCommentsNotificationsIncludeDocumentName).removeDuplicates()
        )

        Publishers.CombineLatest(partial1, partial2)
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
            .removeDuplicates()
            .receive(on: scheduler)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }
}
