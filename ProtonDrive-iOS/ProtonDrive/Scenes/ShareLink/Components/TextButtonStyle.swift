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

#if os(iOS)
struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    let variant: ButtonVariant

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
          .foregroundColor(color(for: configuration))
          .padding(.vertical)
          .padding(.horizontal, horizontalPadding)
          .fixedSize(horizontal: isFixedWidth, vertical: true)
    }

    private func color(for configuration: Configuration) -> Color {
        if isEnabled {
            return configuration.isPressed ? ColorProvider.BrandDarken20 : ColorProvider.TextAccent
        } else {
            return ColorProvider.TextDisabled
        }
    }

    private var isFixedWidth: Bool {
        switch variant {
        case .full:
            return false
        case .contained:
            return true
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .full:
            return 0
        case .contained:
            return 16
        }
    }
}
#endif
