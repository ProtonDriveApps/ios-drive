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

import Foundation
import PDClient

public class LocalSettings: NSObject {
    @SettingsStorage("sortPreferenceCache") private var sortPreferenceCache: SortPreference.RawValue?
    @SettingsStorage("layoutPreferenceCache") private var layoutPreferenceCache: LayoutPreference.RawValue?
    @SettingsStorage("isUploadingDisclaimerActiveValue") private var isUploadingDisclaimerActiveValue: Bool?
    @SettingsStorage("isOnboarded") private var isOnboardedValue: Bool?

    @SettingsStorage("optOutFromTelemetry") var optOutFromTelemetry: Bool?
    @SettingsStorage("optOutFromCrashReports") var optOutFromCrashReports: Bool?
    @SettingsStorage("isNoticationPermissionsSkipped") public var isNoticationPermissionsSkipped: Bool?
    @SettingsStorage("isPhotosBackupEnabledValue") private(set) var isPhotosBackupEnabledValue: Bool?
    @SettingsStorage("isPhotosBackupConnectionConstrainedValue") private(set) var isPhotosBackupConnectionConstrainedValue: Bool?
    @SettingsStorage("isPhotosNotificationsPermissionsSkipped") public var isPhotosNotificationsPermissionsSkipped: Bool?
    @SettingsStorage("isPhotosMediaTypeImageSupportedValue") private(set) var isPhotosMediaTypeImageSupportedValue: Bool?
    @SettingsStorage("isPhotosMediaTypeVideoSupportedValue") private(set) var isPhotosMediaTypeVideoSupportedValue: Bool?
    @SettingsStorage("photosBackupNotOlderThanValue") private(set) var photosBackupNotOlderThanValue: Date?

    @SettingsStorage("photosEnabled") public var photosEnabledValue: Bool?
    @SettingsStorage("photosUploadDisabled") public var photosUploadDisabledValue: Bool?
    @SettingsStorage("photosBackgroundSyncEnabled") public var photosBackgroundSyncEnabledValue: Bool?
    @SettingsStorage("logsCompressionDisabledValue") public var logsCompressionDisabledValue: Bool?
    @SettingsStorage("domainReconnectionEnabledValue") public var domainReconnectionEnabledValue: Bool?
    @SettingsStorage("postMigrationJunkFilesCleanupValue") public var postMigrationJunkFilesCleanupValue: Bool?
    @SettingsStorage("newTrayAppMenuEnabledValue") public var newTrayAppMenuEnabledValue: Bool?

    @SettingsStorage("DriveiOSLogCollection") public var driveiOSLogCollection: Bool?
    @SettingsStorage("DriveiOSLogCollectionDisabled") public var driveiOSLogCollectionDisabled: Bool?

    public init(suite: SettingsStorageSuite) {
        super.init()

        self._sortPreferenceCache.configure(with: suite)
        self._layoutPreferenceCache.configure(with: suite)
        self._optOutFromTelemetry.configure(with: suite)
        self._optOutFromCrashReports.configure(with: suite)
        self._isOnboardedValue.configure(with: suite)
        self._isUploadingDisclaimerActiveValue.configure(with: suite)
        self._isNoticationPermissionsSkipped.configure(with: suite)
        self._isPhotosBackupEnabledValue.configure(with: suite)
        self._isPhotosBackupConnectionConstrainedValue.configure(with: suite)
        self._isPhotosNotificationsPermissionsSkipped.configure(with: suite)
        self._isPhotosMediaTypeImageSupportedValue.configure(with: suite)
        self._isPhotosMediaTypeVideoSupportedValue.configure(with: suite)
        self._photosBackupNotOlderThanValue.configure(with: suite)
        self._photosEnabledValue.configure(with: suite)
        self._photosUploadDisabledValue.configure(with: suite)
        self._photosBackgroundSyncEnabledValue.configure(with: suite)
        self._logsCompressionDisabledValue.configure(with: suite)
        self._driveiOSLogCollection.configure(with: suite)
        self._driveiOSLogCollectionDisabled.configure(with: suite)
        self._domainReconnectionEnabledValue.configure(with: suite)
        self._postMigrationJunkFilesCleanupValue.configure(with: suite)
        self._newTrayAppMenuEnabledValue.configure(with: suite)

        self._driveiOSLogCollection.configure(with: suite)
        self._driveiOSLogCollectionDisabled.configure(with: suite)

        if let sortPreferenceCache = self.sortPreferenceCache {
            nodesSortPreference = SortPreference(rawValue: sortPreferenceCache) ?? SortPreference.default
        } else {
            nodesSortPreference = SortPreference.default
        }

        setDynamicVariables()
    }

    /// KVO compliant dynamic variables need to be set inidividually after initialization / cleanup
    private func setDynamicVariables() {
        nodesLayoutPreference = LayoutPreference(cachedValue: layoutPreferenceCache)
        isUploadingDisclaimerActive = isUploadingDisclaimerActiveValue ?? true
        isPhotosBackupEnabled = isPhotosBackupEnabledValue ?? false
        isPhotosBackupConnectionConstrained = isPhotosBackupConnectionConstrainedValue ?? true
        isPhotosMediaTypeImageSupported = isPhotosMediaTypeImageSupportedValue ?? true
        isPhotosMediaTypeVideoSupported = isPhotosMediaTypeVideoSupportedValue ?? true
        photosBackupNotOlderThan = photosBackupNotOlderThanValue ?? .distantPast
        photosEnabled = photosEnabledValue ?? false
        photosUploadDisabled = photosUploadDisabledValue ?? false
        photosBackgroundSyncEnabled = photosBackgroundSyncEnabledValue ?? false
        logsCompressionDisabled = logsCompressionDisabledValue ?? false
        logCollectionEnabled = driveiOSLogCollection ?? false
        logCollectionDisabled = driveiOSLogCollectionDisabled ?? false
        domainReconnectionEnabled = domainReconnectionEnabledValue ?? false
        postMigrationJunkFilesCleanup = postMigrationJunkFilesCleanupValue ?? false
        newTrayAppMenuEnabled = newTrayAppMenuEnabledValue ?? false
    }

    public func cleanUp() {
        self.sortPreferenceCache = nil
        self.layoutPreferenceCache = nil
        self.optOutFromTelemetry = nil
        self.optOutFromCrashReports = nil
        // self.isOnboardedValue needs no clean up - we only show it for first login ever
        self.isUploadingDisclaimerActiveValue = nil
        self.isNoticationPermissionsSkipped = nil
        self.isPhotosBackupEnabledValue = nil
        self.isPhotosBackupConnectionConstrainedValue = nil
        self.isPhotosNotificationsPermissionsSkipped = nil
        self.isPhotosMediaTypeImageSupportedValue = nil
        self.isPhotosMediaTypeVideoSupportedValue = nil
        self.photosEnabledValue = nil
        self.photosUploadDisabledValue = nil
        self.photosBackgroundSyncEnabledValue = nil
        self.logsCompressionDisabledValue = nil
        self.domainReconnectionEnabledValue = nil
        self.postMigrationJunkFilesCleanupValue = nil
        self.newTrayAppMenuEnabledValue = nil
        setDynamicVariables()
    }

    @objc public dynamic var nodesSortPreference: SortPreference = SortPreference.default {
        willSet {
            self.sortPreferenceCache = newValue.rawValue
        }
    }

    @objc public dynamic var nodesLayoutPreference: LayoutPreference = LayoutPreference.default {
        willSet {
            self.layoutPreferenceCache = newValue.rawValue
        }
    }

    @objc public dynamic var isUploadingDisclaimerActive: Bool = true {
        willSet {
            isUploadingDisclaimerActiveValue = newValue
        }
    }

    @objc public dynamic var isPhotosBackupEnabled: Bool = false {
        willSet {
            isPhotosBackupEnabledValue = newValue
        }
    }

    @objc public dynamic var isPhotosBackupConnectionConstrained: Bool = true {
        willSet {
            isPhotosBackupConnectionConstrainedValue = newValue
        }
    }

    @objc public dynamic var isPhotosMediaTypeImageSupported: Bool = true {
        willSet {
            isPhotosMediaTypeImageSupportedValue = newValue
        }
    }

    @objc public dynamic var isPhotosMediaTypeVideoSupported: Bool = true {
        willSet {
            isPhotosMediaTypeVideoSupportedValue = newValue
        }
    }

    @objc public dynamic var photosBackupNotOlderThan: Date = .distantPast {
        willSet {
            photosBackupNotOlderThanValue = newValue
        }
    }

    @objc public dynamic var photosEnabled: Bool = false {
        willSet {
            photosEnabledValue = newValue
        }
    }

    @objc public dynamic var photosUploadDisabled: Bool = false {
        willSet {
            photosUploadDisabledValue = newValue
        }
    }

    @objc public dynamic var photosBackgroundSyncEnabled: Bool = false {
        willSet {
            photosBackgroundSyncEnabledValue = newValue
        }
    }

    @objc public dynamic var logsCompressionDisabled: Bool = false {
        willSet {
            logsCompressionDisabledValue = newValue
        }
    }

    @objc public dynamic var domainReconnectionEnabled: Bool = false {
        willSet {
            domainReconnectionEnabledValue = newValue
        }
    }

    @objc public dynamic var postMigrationJunkFilesCleanup: Bool = false {
        willSet {
            postMigrationJunkFilesCleanupValue = newValue
        }
    }

    @objc public dynamic var newTrayAppMenuEnabled: Bool = false {
        willSet {
            newTrayAppMenuEnabledValue = newValue
        }
    }

    @objc public dynamic var logCollectionEnabled: Bool = false {
        willSet {
            driveiOSLogCollection = newValue
        }
    }

    @objc public dynamic var logCollectionDisabled: Bool = false {
        willSet {
            driveiOSLogCollectionDisabled = newValue
        }
    }

    public var isOnboarded: Bool {
        get { isOnboardedValue == true }
        set { isOnboardedValue = (newValue ? true : nil) }
    }
}

public extension LocalSettings {
    // Please do not create new instances of this class. Use the shared instance instead.
    static let shared = LocalSettings(suite: .group(named: Constants.appGroup))
}
