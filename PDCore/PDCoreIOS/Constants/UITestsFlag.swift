// Copyright (c) 2023 Proton AG
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

#if DEBUG

import PDCore

public extension UITestsFlag {
    static let clearAllPreference = UITestsFlag(content: "--clear_all_preference")
    static let skipNotificationPermissions = UITestsFlag(content: "--skip_notifications_permissions")
    static let skipOnboarding = UITestsFlag(content: "--skip_onboarding")
    static let skipUpsell = UITestsFlag(content: "--skip_upsell")
    static let defaultOnboarding = UITestsFlag(content: "--default_onboarding")
    static let defaultUpsell = UITestsFlag(content: "--default_upsell")
    static let mockCellularConnection = UITestsFlag(content: "--mock_cellular_connection")
    static let mockNoConnection = UITestsFlag(content: "--mock_no_connection")
    static let filesAsDefaultTab = UITestsFlag(content: "--files_as_default_tab")
    static let clearDefaultTab = UITestsFlag(content: "--clear_default_tab")
    static let defaultPhotoUpsell = UITestsFlag(content: "--default_photo_upsell")
    static let skipPhotoUpsell = UITestsFlag(content: "--skip_photo_upsell")
    static let defaultNewFeaturePromote = UITestsFlag(content: "--default_new_feature_promote")
    static let skipNewFeaturePromote = UITestsFlag(content: "--skip_new_feature_promote")
    /// When upload photo, stop removing invalid characters
    static let skipPhotoNameCorrection = UITestsFlag(content: "--skip_photo_name_correction")
    static let skipMigrationPopup = UITestsFlag(content: "--skip_migration_popup")
}

#endif
