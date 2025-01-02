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

import UIKit
import ProtonCoreUIFoundations
import PDLocalization

// This extension will act as an adapted version of the domain TabBarItem into a view model/UI version of it
extension TabBarItem {
    var icon: UIImage {
        switch self {
        case .files:
            return IconProvider.folder
        case .photos:
            return IconProvider.image
        case .shared:
            return IconProvider.link
        case .sharedWithMe:
            return IconProvider.users
        }
    }

    var title: String {
        switch self {
        case .files:
            return Localization.tab_bar_title_files
        case .photos:
            return Localization.tab_bar_title_photos
        case .shared:
            return Localization.tab_bar_title_shared
        case .sharedWithMe:
            return Localization.tab_bar_title_shared_with_me
        }
    }

    var identifierInTabBar: String {
        switch self {
        case .files:
            return "TabBar.Files"
        case .photos:
            return "TabBar.Photos"
        case .shared:
            return "TabBar.Shared"
        case .sharedWithMe:
            return "TabBar.SharedWithMe"
        }
    }

    var tag: Int {
        rawValue
    }
}
