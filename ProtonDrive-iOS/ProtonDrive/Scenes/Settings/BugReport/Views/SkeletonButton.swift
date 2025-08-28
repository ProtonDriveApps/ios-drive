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

import SwiftUI
import ProtonCoreUIFoundations

struct SkeletonButton: View {
    let text: String
    let icon: Image
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label {
                Text(text)
            } icon: {
                icon
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 6)
            .padding(.vertical)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorProvider.BrandNorm, lineWidth: 2)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorProvider.BrandNorm.opacity(0.1))
                }
            )
        }
        .tint(ColorProvider.TextAccent)
    }
}
