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

import PDCore

/// Persists whether the one-time admin-sharing tooltip ("editors can now manage sharing") has already
/// been shown. Extracted behind a protocol so the view model stays unit-testable with a lightweight mock.
protocol AdminSharingTooltipStore: AnyObject {
    var hasSeenAdminSharingTooltip: Bool { get set }
}

/// `LocalSettings`-backed implementation. The flag is account-wide ("show once ever per user") and
/// is reset on logout via `LocalSettings.cleanUp()`.
final class LocalSettingsAdminSharingTooltipStore: AdminSharingTooltipStore {
    private let localSettings: LocalSettings

    init(localSettings: LocalSettings) {
        self.localSettings = localSettings
    }

    var hasSeenAdminSharingTooltip: Bool {
        get { localSettings.didShowEditorPermissionsTooltip ?? false }
        set { localSettings.didShowEditorPermissionsTooltip = newValue }
    }
}
