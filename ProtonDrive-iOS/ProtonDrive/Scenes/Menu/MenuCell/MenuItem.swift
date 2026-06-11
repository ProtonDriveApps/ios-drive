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

import SwiftUI
import ProtonCoreUIFoundations
import PDLocalization

enum MenuItem {
    case home
    case trash
    case servicePlans
    case settings
    case feedback
    case logout
    case sharedByMe
    case storageBonusPromo

    var icon: Image {
        switch self {
        case .home: return IconProvider.house
        case .trash: return IconProvider.trash
        case .servicePlans: return IconProvider.pencil
        case .settings: return IconProvider.cogWheel
        case .feedback: return IconProvider.bug
        case .logout: return IconProvider.arrowOutFromRectangle
        case .sharedByMe: return IconProvider.link
        case .storageBonusPromo: return IconProvider.gift
        }
    }

    var text: String {
        switch self {
        case .home: return Localization.menu_text_home
        case .trash: return Localization.menu_text_trash
        case .servicePlans: return Localization.menu_text_subscription
        case .settings: return Localization.menu_text_settings
        case .feedback: return Localization.menu_text_feedback
        case .logout: return Localization.menu_text_logout
        case .sharedByMe: return Localization.menu_text_shared_by_me
        case .storageBonusPromo: return Localization.menu_text_storage_bonus_promo
        }
    }

    var textColor: Color? {
        switch self {
        default: return nil
        }
    }

    /// Will produce identifier with the following shape: `MenuItem.home`
    var identifier: String {
        "MenuItem.\(self)"
    }
}
