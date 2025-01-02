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

import PDLocalization
import SwiftUI
import UIKit

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
            .title(Localization.protection_section_header_protection)
            .appendRowIfAvailable(bioCell(with: locker, and: router))
            .appendRow(pinCell(with: locker, and: router))
            .footer(Localization.protection_section_footer_protection)
            .build()
    }

    static func autolockSection(locker: Locker, router: SettingsSecurityRouter) -> PMSettingsSectionViewModel {
        return PMSettingsSectionBuilder()
            .title(Localization.protection_timings_section_header)
            .appendRow(autolockCell(with: locker, and: router))
            .footer(Localization.protection_timing_section_footer)
            .build()
    }

    static var swiftUICellConfig: PMCellSuplier {
        let text = Localization.protection_info_banner_text
        return SwiftUIHostCellConfiguration {
            NotificationBanner(message: text, style: .inverted, padding: .bottom)
        }
    }

    static func bioCell(with locker: Locker, and router: SettingsSecurityRouter) -> PMSwitchSecurityCellConfiguration? {
        let bioMode = BiometryType.currentType
        switch bioMode {
        case .none where locker.isBioProtected:
            let switcher = BioSwitcherDisabler(locker: locker)
            let title = Localization.protection_use_biometry
            return PMSwitchSecurityCellConfiguration(title: title, switcher: switcher)
        case .none:
            return nil
        default:
            let switcher = BioSwitcher(locker: locker)
            let title = Localization.protection_use_use_technology(tech: bioMode.technologyName)
            return PMSwitchSecurityCellConfiguration(title: title, switcher: switcher)
        }
    }

    static func pinCell(with locker: Locker, and router: SettingsSecurityRouter) -> PMSwitchSecurityCellConfiguration {
        let switcher = PinSwitcher(locker: locker, router: router)
        return PMSwitchSecurityCellConfiguration(title: Localization.password_config_title_use_pin, switcher: switcher)
    }

    static func autolockCell(with locker: AutoLocker, and router: SettingsSecurityRouter) -> PMCellSuplier {
        PMAutolockSelectionCellConfiguration(autoLocker: locker, router: router)
    }
}
