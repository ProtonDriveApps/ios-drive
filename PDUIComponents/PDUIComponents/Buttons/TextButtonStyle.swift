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
    let padding: ViewPadding

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(color(for: configuration))
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .fixedSize(horizontal: true, vertical: true)
    }

    private func color(for configuration: Configuration) -> Color {
        if isEnabled {
            return configuration.isPressed ? ColorProvider.BrandDarken20 : ColorProvider.TextAccent
        } else {
            return ColorProvider.TextDisabled
        }
    }

    private var verticalPadding: Double {
        switch padding {
        case .none:
            return 0
        case .default:
            return 10
        }
    }

    private var horizontalPadding: Double {
        switch padding {
        case .none:
            return 0
        case .default:
            return 16
        }
    }

    private var fontWeight: Font.Weight {
        switch variant {
        case .regular:
            return .regular
        case .regularBold:
            return .bold
        case .smallBold:
            return .semibold
        }
    }

    private var font: Font {
        switch variant {
        case .regular, .regularBold:
            return .body
        case .smallBold:
            return .subheadline
        }
    }
}
#endif
