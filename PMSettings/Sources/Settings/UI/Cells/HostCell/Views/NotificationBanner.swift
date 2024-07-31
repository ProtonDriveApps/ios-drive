// Copyright (c) 2024 Proton AG
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

struct NotificationBanner: View {
    enum Style {
        case normal
        case inverted
    }

    enum Padding {
        case vertical
        case bottom
    }

    let message: String
    let style: Style
    let padding: Padding

    init(message: String, style: Style, padding: Padding) {
        self.message = message
        self.style = style
        self.padding = padding
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            IconProvider.exclamationCircle
                .renderingMode(.template)
                .foregroundColor(color)

            Text(message)
                .font(.subheadline)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibility(identifier: "NotificationBanner.text")
        }
        .padding()
        .background(backgroundColor.cornerRadius(8))
        .padding(.horizontal)
    }

    private var color: Color {
        switch style {
        case .normal:
            return ColorProvider.TextNorm
        case .inverted:
            return ColorProvider.TextInverted
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .normal:
            return ColorProvider.BackgroundSecondary
        case .inverted:
            return ColorProvider.NotificationNorm
        }
    }
}
