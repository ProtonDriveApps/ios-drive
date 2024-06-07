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

public struct RoundIconSmall: View {
    let icon: Image
    let color: Color
    let background: Color

    public init(icon: Image, color: Color = .clear, background: Color = .clear) {
        self.icon = icon
        self.color = color
        self.background = background
    }
    
    public var body: some View {
        icon
            .resizable()
            .frame(width: 12, height: 12)
            .foregroundColor(color)
            .background(
                Circle()
                    .fill(background)
                    .frame(width: 12, height: 12)
            )
    }
}
