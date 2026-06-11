//
//  PMSettingsViewModel.swift
//  ProtonCore-Settings - Created on 24.09.2020.
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

public final class PMSettingsViewModel: PMSettingsViewModelProtocol {
    public private(set) var sections: [PMSettingsSectionViewModel]
    public let version: String
    public var sectionsDidUpdate: ((Int) -> Void)?

    public init(sections: [PMSettingsSectionViewModel], version: String) {
        self.sections = sections
        self.version = version
    }

    public var pageTitle: String {
        Localization.general_settings
    }

    public var footer: String? {
        Localization.setting_app_version(version: version)
    }

    public func update(section: PMSettingsSectionViewModel) {
        guard let index = sections.firstIndex(where: { $0.title == section.title }) else { return }
        sections[index] = section
        sectionsDidUpdate?(index)
    }
}
