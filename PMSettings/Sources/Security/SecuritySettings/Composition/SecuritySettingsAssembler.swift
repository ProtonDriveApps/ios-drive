//
//  SecuritySettingsAssembler.swift
//  ProtonCore-Settings - Created on 04.10.2020.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import UIKit
import SwiftUI

final class SecuritySettingsAssembler {
    static func assemble(locker: Locker, isPhotosEnabled: @escaping () -> Bool) -> UIViewController {
        let viewController = SecuritySettingsViewController()
        let router = PMSecuritySettingsRouter(view: viewController)
        var sections = [protectionSection(locker: locker, router: router), autolockSection(locker: locker, router: router) ]

        // Feature flag configuration, remove when the FF is no longer needed
        if isPhotosEnabled() {
            sections.insert(bannerSection(), at: 0)
            viewController.contentInsetAdjustmentBehavior = .never
        }
        let viewModel = SecuritySettingsViewModel(sections: sections)
        viewController.viewModel = viewModel
        viewController.router = router
        router.refreshSections = { [unowned viewModel] in viewModel.onLoadFinished?() }
        return viewController
    }
}

private extension SecuritySettingsAssembler {
    static func bannerSection() -> PMSettingsSectionViewModel {
        return PMSettingsSectionBuilder()
            .title(nil)
            .appendRow(swiftUICellConfig)
            .build()
    }

    static func protectionSection(locker: Locker, router: SettingsSecurityRouter) -> PMSettingsSectionViewModel {
        return PMSettingsSectionBuilder()
            .title("Protection")
            .appendRowIfAvailable(bioCell(with: locker, and: router))
            .appendRow(pinCell(with: locker, and: router))
            .footer("Turn this feature on to auto-lock and use a PIN code or biometric sensor to unlock it.")
            .build()
    }

    static func autolockSection(locker: Locker, router: SettingsSecurityRouter) -> PMSettingsSectionViewModel {
        return PMSettingsSectionBuilder()
            .title("Timings")
            .appendRow(autolockCell(with: locker, and: router))
            .footer("The PIN code will be required after some minutes of the app being in the background or after exiting the app.")
            .build()
    }

    static var swiftUICellConfig: PMCellSuplier {
        return SwiftUIHostCellConfiguration {
            NotificationBanner(message: #"Enabling auto-lock stops background processes unless set to "After launch.""#, style: .inverted, padding: .bottom)
        }
    }

    static func bioCell(with locker: Locker, and router: SettingsSecurityRouter) -> PMSwitchSecurityCellConfiguration? {
        let bioMode = BiometryType.currentType
        switch bioMode {
        case .none where locker.isBioProtected:
            let switcher = BioSwitcherDisabler(locker: locker)
            return PMSwitchSecurityCellConfiguration(title: "Use Biometry", switcher: switcher)
        case .none:
            return nil
        default:
            let switcher = BioSwitcher(locker: locker)
            return PMSwitchSecurityCellConfiguration(title: "Use " + bioMode.technologyName, switcher: switcher)
        }
    }

    static func pinCell(with locker: Locker, and router: SettingsSecurityRouter) -> PMSwitchSecurityCellConfiguration {
        let switcher = PinSwitcher(locker: locker, router: router)
        return PMSwitchSecurityCellConfiguration(title: "Use PIN code", switcher: switcher)
    }

    static func autolockCell(with locker: AutoLocker, and router: SettingsSecurityRouter) -> PMCellSuplier {
        PMAutolockSelectionCellConfiguration(autoLocker: locker, router: router)
    }
}
