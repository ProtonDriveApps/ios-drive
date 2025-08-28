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

import Foundation
import SwiftUI
import ProtonCoreUIFoundations

#if os(iOS)
public struct RoundedSelectionView: View {
    private let isSelected: Bool
    private let iconSize: CGFloat
    private let viewSize: CGFloat

    public init(isSelected: Bool, iconSize: CGFloat = 18, viewSize: CGFloat = 21) {
        self.isSelected = isSelected
        self.iconSize = iconSize
        self.viewSize = viewSize
    }

    public var body: some View {
        IconProvider.checkmark
            .resizable()
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(isSelected ? ColorProvider.White : Color.clear)
            .background(
                background
                    .frame(width: viewSize, height: viewSize)
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
#endif
