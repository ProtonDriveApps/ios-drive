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
import ProtonCore_UIFoundations

enum MenuItem {
    case myFiles
    case trash
    case servicePlans
    case settings
    case feedback
    case logout

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
        }
    }

    var text: String {
        switch self {
        case .myFiles:
            return "My files"
        case .trash:
            return "Trash"
        case .servicePlans:
            return "Subscription"
        case .settings:
            return "Settings"
        case .feedback:
            return "Report a problem"
        case .logout:
            return "Sign out"
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
