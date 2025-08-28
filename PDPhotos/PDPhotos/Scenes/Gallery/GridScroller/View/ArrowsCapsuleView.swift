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

import ProtonCoreUIFoundations
import SwiftUI

struct ArrowsCapsuleView: View {
    static let height: CGFloat = 37
    static let width: CGFloat = 32

    var body: some View {
        ZStack(alignment: .center) {
            InternalIcon.chevronUpDown
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(ColorProvider.TextNorm)
        }
        .frame(width: ArrowsCapsuleView.width, height: ArrowsCapsuleView.height)
        .modifier(CapsuleViewBackgroundModifier())
    }
}
