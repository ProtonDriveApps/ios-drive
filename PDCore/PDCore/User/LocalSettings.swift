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
    
    @SettingsStorage("optOutFromTelemetry") var optOutFromTelemetry: Bool?
    @SettingsStorage("optOutFromCrashReports") var optOutFromCrashReports: Bool?
    @SettingsStorage("isOnboarded") public var isOnboarded: Bool?
    @SettingsStorage("isNoticationPermissionsSkipped") public var isNoticationPermissionsSkipped: Bool?

    public init(suite: SettingsStorageSuite) {
        super.init()
        
        self._sortPreferenceCache.configure(with: suite)
        self._layoutPreferenceCache.configure(with: suite)
        self._optOutFromTelemetry.configure(with: suite)
        self._optOutFromCrashReports.configure(with: suite)
        self._isOnboarded.configure(with: suite)
        self._isUploadingDisclaimerActiveValue.configure(with: suite)
        self._isNoticationPermissionsSkipped.configure(with: suite)

        if let sortPreferenceCache = self.sortPreferenceCache {
            nodesSortPreference = SortPreference(rawValue: sortPreferenceCache) ?? SortPreference.default
        } else {
            nodesSortPreference = SortPreference.default
        }

        nodesLayoutPreference = LayoutPreference(cachedValue: layoutPreferenceCache)
        isUploadingDisclaimerActive = isUploadingDisclaimerActiveValue ?? true
    }
    
    public func cleanUp() {
        self.sortPreferenceCache = nil
        self.layoutPreferenceCache = nil
        self.optOutFromTelemetry = nil
        self.optOutFromCrashReports = nil
        // self.isOnboarded needs no clean up - we only show it for first login ever
        self.isUploadingDisclaimerActiveValue = nil
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
}
