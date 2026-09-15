// Copyright (c) 2026 Proton AG
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

import SwiftUI
import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations

public struct UpgradeRequirementBannerView: View {
    let level: UpgradeRequirementLevel
    let handling: UpgradeRequirementHandling

    public init(
        level: UpgradeRequirementLevel,
        handling: UpgradeRequirementHandling
    ) {
        self.level = level
        self.handling = handling
    }

    public var body: some View {
        let message = Localization.Update_require_message
        let upgradeButtonTitle = Localization.setting_system_update_button
        if level != .none {
            if level == .recommend {
                ActionBanner(
                    message: message,
                    trailingAction: .close(onClose)
                )
                .backgroundColor(ColorProvider.NotificationWarning)
            } else {
                ActionBanner(
                    message: message,
                    trailingAction: .text(title: upgradeButtonTitle, action: openAppStore)
                )
                .backgroundColor(ColorProvider.NotificationError)
            }
        }
    }

    private func onClose() {
        handling.closeUpgradeHintBanner()
    }

    private func openAppStore() {
        handling.openAppStore()
    }
}
