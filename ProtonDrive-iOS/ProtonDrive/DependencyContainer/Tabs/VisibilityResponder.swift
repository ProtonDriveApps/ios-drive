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
import PDCoreIOS
import ProtonCoreFeatureFlags

public protocol VisibilityResponder {
    func canHandle(_ item: VisibilityItem) -> Bool
    func shouldShow(_ item: VisibilityItem) -> Bool
}

public final class PhotosTabVisibilityResponder: VisibilityResponder {
    private let localSettings: LocalSettings
    private let repository: ProtonCoreFeatureFlags.FeatureFlagsRepository
    private let b2bFeatureFlag = ProtonCoreDriveFeatureFlag.driveB2BPhotosUpload

    init(localSettings: LocalSettings, repository: ProtonCoreFeatureFlags.FeatureFlagsRepository) {
        self.localSettings = localSettings
        self.repository = repository
    }

    public func canHandle(_ item: VisibilityItem) -> Bool {
        item == .photosTab
    }

    public func shouldShow(_ item: VisibilityItem) -> Bool {
        // Non B2B users can always see the Photos tab
        guard localSettings.isB2BUser else {
            return true
        }

        // If the feature flag is not enable we don't limit the uploads for B2B users
        guard repository.isEnabled(b2bFeatureFlag, reloadValue: true) else {
            return true
        }
        // If the feature flag is enabled, we check the B2B photos setting
        let b2bPhotosEnabled = localSettings.driveSettingsB2BPhotosEnabled
        return b2bPhotosEnabled
    }
}

public final class ComputersTabVisibilityResponder: VisibilityResponder {
    private let featureFlags: FeatureFlagsControllerProtocol

    public init(featureFlags: FeatureFlagsControllerProtocol) {
        self.featureFlags = featureFlags
    }

    public func canHandle(_ item: VisibilityItem) -> Bool {
        item == .computersTab
    }

    public func shouldShow(_ item: VisibilityItem) -> Bool {
        featureFlags.hasComputers
    }
}

public final class SharedWithMeTabVisibilityResponder: VisibilityResponder {
    private let featureFlags: FeatureFlagsControllerProtocol

    public init(featureFlags: FeatureFlagsControllerProtocol) {
        self.featureFlags = featureFlags
    }

    public func canHandle(_ item: VisibilityItem) -> Bool {
        item == .sharedWithMeTab
    }

    public func shouldShow(_ item: VisibilityItem) -> Bool {
        featureFlags.hasSharing
    }
}

public final class SharedTabVisibilityResponder: VisibilityResponder {
    private let featureFlags: FeatureFlagsControllerProtocol

    public init(featureFlags: FeatureFlagsControllerProtocol) {
        self.featureFlags = featureFlags
    }

    public func canHandle(_ item: VisibilityItem) -> Bool {
        item == .sharedTab
    }

    public func shouldShow(_ item: VisibilityItem) -> Bool {
        !featureFlags.hasSharing
    }
}
