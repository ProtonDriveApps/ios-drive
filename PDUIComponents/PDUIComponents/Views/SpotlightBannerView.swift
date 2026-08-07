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
import ProtonCoreUIFoundations
import SwiftUI

/// A dismissible, persistent informational callout: optional leading icon, bold title, body text,
/// and a trailing close button. Used for one-time contextual feature spotlights.
public struct SpotlightBannerView: View {
    private let icon: UIImage?
    private let title: String
    private let message: String
    private let accessibilityIdentifier: String?
    private let onClose: () -> Void

    public init(
        icon: UIImage? = nil,
        title: String,
        message: String,
        accessibilityIdentifier: String? = nil,
        onClose: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onClose = onClose
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(ColorProvider.IconAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ColorProvider.TextNorm)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.footnote)
                    .foregroundColor(ColorProvider.TextWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(uiImage: IconProvider.cross)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(ColorProvider.IconWeak)
            }
            .accessibilityIdentifier(accessibilityIdentifier.map { "\($0).close" } ?? "SpotlightBannerView.close")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorProvider.BackgroundNorm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorProvider.SeparatorNorm, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "SpotlightBannerView")
    }
}
#endif
