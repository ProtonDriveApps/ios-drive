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

struct RoundedSelectionView: View {
    private let isSelected: Bool

    init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    var body: some View {
        IconProvider.checkmark
            .resizable()
            .frame(width: 18, height: 18)
            .foregroundColor(isSelected ? ColorProvider.White : Color.clear)
            .background(
                background
                    .frame(width: 21, height: 21)
            )
    }

    private var background: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? ColorProvider.BrandNorm : ColorProvider.IconWeak, lineWidth: 1)
            Circle()
                .fill(isSelected ? ColorProvider.BrandNorm : Color.clear)
        }
    }
}
