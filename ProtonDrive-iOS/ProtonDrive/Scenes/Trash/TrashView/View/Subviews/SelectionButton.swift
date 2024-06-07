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

struct SelectionButton: View {
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Spacer()

            IconProvider.checkmark
                .resizable()
                .frame(width: 21, height: 21)
                .foregroundColor(isSelected ? Color.white : Color.clear)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorProvider.BrandNorm, lineWidth: 2)
                            .frame(width: 21, height: 21)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? ColorProvider.BrandNorm : ColorProvider.BackgroundSecondary)
                            .frame(width: 21, height: 21)
                    }
                )

            Spacer()
        }
        .background(ColorProvider.BackgroundNorm)
    }
}
