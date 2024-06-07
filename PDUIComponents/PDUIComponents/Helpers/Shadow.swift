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

enum ShadowNumber: CGFloat {
    // these raw values are blur values from design system
    case one = 2, two = 4, three = 8, four = 12, five = 16
}

extension View {
    func shadow(_ number: ShadowNumber) -> some View {
    // FIXME: this does not show the shadow correctly
        self.shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 0)
            .shadow(color: .black.opacity(0.1), radius: number.rawValue, x: 0, y: 1)
    }
}
