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

public struct CellButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    let backgroundPressedOpacity: Double
    let totalOpacity: Double
    let backgroundColor: Color

    public init(isEnabled: Bool = true, background: Color = Color.secondary) {
        self.backgroundPressedOpacity = isEnabled ? 1.0 : 0.0
        self.totalOpacity = isEnabled ? 1.0 : 0.7
        self.backgroundColor = background
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
        .overlay(
            backgroundColor
            .cornerRadius(.medium)
            .blendMode(colorScheme == .dark ? .lighten : .darken)
            .opacity(configuration.isPressed ? backgroundPressedOpacity : 0)
        )
        .opacity(totalOpacity)
    }
}
