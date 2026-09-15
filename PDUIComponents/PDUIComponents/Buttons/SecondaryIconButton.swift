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

#if os(iOS)
public struct SecondaryIconButton: View {
    @Environment(\.isEnabled) private var isEnabled

    private let title: String
    private let icon: Image
    private let height: CGFloat
    private let action: () -> Void

    public init(
        title: String,
        icon: Image,
        height: CGFloat = 40,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(ColorProvider.TextAccent)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorProvider.SeparatorNorm, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
