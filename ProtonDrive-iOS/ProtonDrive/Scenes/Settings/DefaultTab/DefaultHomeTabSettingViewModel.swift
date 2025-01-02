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

import Combine
import Foundation
import PDCore
import PMSettings
import ProtonCoreUIFoundations
import PDLocalization

final class DefaultHomeTabSettingViewModel: PMDrillDownCellViewModel {
    var accessibilityIdentifier: String { "default_home_tab" }

    private let localSettings: LocalSettings
    private var cancellable: AnyCancellable?
    private var currentSelection: TabBarItem?

    var title: String = Localization.settings_default_home_tab

    var preview: String? {
        currentSelection?.title
    }

    var previewAccessibilityIdentifier: String? {
        currentSelection?.settingsAccessibilityIdentifier
    }

    init(localSettings: LocalSettings) {
        self.localSettings = localSettings

        cancellable = localSettings
            .publisher(for: \.defaultHomeTabTag)
            .sink { tag in
                self.currentSelection = TabBarItem(rawValue: tag)
            }
    }
}

extension TabBarItem {
    var settingsAccessibilityIdentifier: String {
        switch self {
        case .files:
            return "Files"
        case .photos:
            return "Photos"
        case .shared:
            return "Shared"
        case .sharedWithMe:
            return "SharedWithMe"
        }
    }
}
