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

#if os(iOS)
import SwiftUI

public struct BlurredBackgroundProgressView: View {
    private let progress: CGFloat
    @Environment(\.colorScheme) var colorScheme

    public init(progress: CGFloat = 0) {
        self.progress = progress
    }

    public var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(blurColor)
                .background(.ultraThinMaterial)
                .overlay(alignment: .leading) {
                    topColor
                        .frame(width: geometry.size.width * progress)
                }
        }
    }

    private var topColor: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "0c0c14") : UIColor.white
        }).opacity(0.9)
    }

    private var blurColor: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "454545") : UIColor(hex: "d8d8d8")
        }).opacity(0.9)
    }
}
#endif
