// Copyright (c) 2024 Proton AG
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
import ProtonCoreKeymaker

protocol LockProtectionEnabledPolicy {
    func isProtectionEnabled() -> Bool
}

final class TimeoutLockProtectionEnabledPolicy: LockProtectionEnabledPolicy {
    private let settingsProvider: SettingsProvider
    private let protectionResource: ProtectionResource

    init(settingsProvider: SettingsProvider, protectionResource: ProtectionResource) {
        self.settingsProvider = settingsProvider
        self.protectionResource = protectionResource
    }

    /// Looks into current user's lock settings (protection & its autolock timeout).
    /// returns `true` if there's a protection set up with autolock timeout
    /// returns `false` if no protection is set up or if there's no timeout (no timeout means the app locks only after relaunch)
    func isProtectionEnabled() -> Bool {
        return protectionResource.isProtected() && settingsProvider.lockTime != .never
    }
}
