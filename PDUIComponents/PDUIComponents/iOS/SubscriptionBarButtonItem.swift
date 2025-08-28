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
import Foundation
import UIKit
import SwiftUI
import ProtonCoreUIFoundations

public struct SubscriptionBarItem: View {
    private var action: () -> Void
    private let identifier: String

    public init(identifier: String = "bar.item.subscribe", action: @escaping () -> Void) {
        self.action = action
        self.identifier = identifier
    }

    public var body: some View {
        let colors: [Color] = [
            Color(red: 109.0 / 255.0, green: 74.0 / 255.0, blue: 1),
            Color(red: 208.0 / 255.0, green: 80.0 / 255.0, blue: 1),
            Color(red: 1, green: 80.0 / 255.0, blue: 194.0 / 255.0),
        ]
        Button(action: {
            action()
        }, label: {
            HStack(spacing: 0) {
                Image(uiImage: IconProvider.brandProtonDrive)
                    .resizable()
                    .foregroundStyle(ColorProvider.IconNorm)
                    .frame(width: 16, height: 16)
                    .padding(.trailing, 2)

                Text("+")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorProvider.TextNorm)
                    .fixedSize()
            }
        })
        .buttonStyle(GradientButtonStyle(colors: colors, horizontalPadding: 6, verticalPadding: 4))
        .accessibilityIdentifier(identifier)
    }
}

#endif
