// Copyright (c) 2026 Proton AG
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
import ProtonCoreUIFoundations
import UIKit

public struct ActionBanner: View {
    public enum TrailingAction {
        case close(() -> Void)
        case text(title: String, action: () -> Void)
        case none
    }

    private let icon: UIImage?
    private let message: String
    private let trailingAction: TrailingAction

    private var backgroundColor: Color = ColorProvider.NotificationNorm
    private var textColor: Color = ColorProvider.TextInverted
    private var iconColor: Color = ColorProvider.IconNorm
    private var iconBackgroundColor: Color = ColorProvider.BackgroundSecondary

    public init(icon: UIImage? = nil, message: String, trailingAction: TrailingAction = .none) {
        self.icon = icon
        self.message = message
        self.trailingAction = trailingAction
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(iconColor)
                    .padding(9)
                    .background(iconBackgroundColor)
                    .clipShape(Circle())
                    .accessibilityIdentifier("ActionBanner.icon")
            }

            Text(message)
                .foregroundColor(textColor)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("ActionBanner.message.\(message)")

            trailingView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor.cornerRadius(.huge))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailingAction {
        case let .close(action):
            Button(action: action) {
                IconProvider.cross
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color.white.opacity(0.2).cornerRadius(2)
            )
            .buttonStyle(.plain)
            .accessibilityIdentifier("ActionBanner.button.close")
        case let .text(title, action):
            Button(action: action) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color.white.opacity(0.2).cornerRadius(2)
            )
            .buttonStyle(.plain)
            .accessibilityIdentifier("ActionBanner.button.\(title)")
        case .none:
            EmptyView()
        }
    }
}

extension ActionBanner {
    public func backgroundColor(_ color: Color) -> Self {
        var copy = self
        copy.backgroundColor = color
        return copy
    }

    public func textColor(_ color: Color) -> Self {
        var copy = self
        copy.textColor = color
        return copy
    }

    public func iconColor(_ color: Color) -> Self {
        var copy = self
        copy.iconColor = color
        return copy
    }

    public func iconBackgroundColor(_ color: Color) -> Self {
        var copy = self
        copy.iconBackgroundColor = color
        return copy
    }
}
#endif
