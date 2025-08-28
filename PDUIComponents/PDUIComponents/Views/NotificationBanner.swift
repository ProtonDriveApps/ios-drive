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

#if os(iOS)
import ProtonCoreUIFoundations
import SwiftUI

public struct NotificationBanner: View {
    public enum Style {
        case normal
        case inverted
        case transparent
    }

    public enum Padding {
        case vertical
        case bottom
        case none
    }

    let message: String
    let style: Style
    let padding: Padding
    let closeBlock: (() -> Void)?

    public init(message: String, style: Style, padding: Padding, closeBlock: (() -> Void)? = nil) {
        self.message = message
        self.style = style
        self.padding = padding
        self.closeBlock = closeBlock
    }

    public var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .padding(12)
                    .accessibility(identifier: "NotificationBanner.text")

                Spacer()

                if let closeBlock {
                    Button(action: closeBlock) {
                        IconProvider.crossBig
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(buttonColor)
                    }
                    .padding(.trailing, 20)
                    .accessibility(identifier: "NotificationBanner.close")
                }
            }
        }
        .background(
            background.cornerRadius(.huge)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, padding == .vertical ? 8 : 0)
        .padding(.bottom, padding == .bottom ? 10 : 0)
    }

    private var textColor: Color {
        switch style {
        case .normal, .transparent:
            return ColorProvider.TextNorm
        case .inverted:
            return ColorProvider.TextInverted
        }
    }

    private var buttonColor: Color {
        switch style {
        case .normal, .transparent:
            return ColorProvider.IconNorm
        case .inverted:
            return ColorProvider.IconInverted
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .normal:
            ColorProvider.BackgroundSecondary
        case .inverted:
            ColorProvider.NotificationNorm
        case .transparent:
            BlurredBackgroundProgressView()
        }
    }
}
#endif
