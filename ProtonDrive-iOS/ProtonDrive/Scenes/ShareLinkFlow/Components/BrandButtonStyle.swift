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

#if os(iOS)
struct BrandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
          .foregroundColor(color(for: configuration))
          .padding(.vertical)
    }

    private func color(for configuration: Configuration) -> Color {
        if isEnabled {
            return configuration.isPressed ? ColorProvider.InteractionNormPressed : ColorProvider.TextAccent
        } else {
            return ColorProvider.TextDisabled
        }
    }
}
#endif