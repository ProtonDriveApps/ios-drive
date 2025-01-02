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

import SwiftUI
import ProtonCoreUIFoundations
import PDLocalization

enum MenuItem {
    case myFiles
    case trash
    case servicePlans
    case settings
    case feedback
    case logout
    case sharedByMe

    var icon: Image {
        switch self {
        case .myFiles:
            return IconProvider.drive
        case .trash:
            return IconProvider.trash
        case .servicePlans:
            return IconProvider.pencil
        case .settings:
            return IconProvider.cogWheel
        case .feedback:
            return IconProvider.bug
        case .logout:
            return IconProvider.arrowOutFromRectangle
        case .sharedByMe:
            return IconProvider.link
        }
    }

    var text: String {
        switch self {
        case .myFiles:
            return Localization.menu_text_my_files
        case .trash:
            return Localization.menu_text_trash
        case .servicePlans:
            return Localization.menu_text_subscription
        case .settings:
            return Localization.menu_text_settings
        case .feedback:
            return Localization.menu_text_feedback
        case .logout:
            return Localization.menu_text_logout
        case .sharedByMe:
            return Localization.menu_text_shared_by_me
        }
    }

    var identifier: String {
        switch self {
        case .myFiles:
            return "MenuItem.myFiles"
        case .trash:
            return "MenuItem.trash"
        case .servicePlans:
            return "MenuItem.subscription"
        case .settings:
            return "MenuItem.settings"
        case .feedback:
            return "MenuItem.feedback"
        case .logout:
            return "MenuItem.logout"
        case .sharedByMe:
            return "MenuItem.sharedByMe"
        }
    }
}

struct MenuCell: View {
    @Environment(\.menuIconSize) var iconSize: CGFloat
    let item: MenuItem

    init(item: MenuItem) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                item.icon
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .padding(.vertical, 4)
                    .foregroundColor(ColorProvider.SidebarIconWeak)

                Text(item.text)
                    .font(.body)
                    .foregroundColor(ColorProvider.SidebarTextNorm)
                    .accessibilityIdentifier(item.identifier)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }
}
