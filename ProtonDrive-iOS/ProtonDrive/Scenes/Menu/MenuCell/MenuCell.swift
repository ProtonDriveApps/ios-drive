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
import PDLocalization

// MARK: - MenuCell View

struct MenuCell: View {
    @Environment(\.menuIconSize) var iconSize: CGFloat
    @Environment(\.isHighlighted) var isHighlighted: Bool
    @Environment(\.hasPulseAnimation) private var isPulseEnabled
    @State private var hasBecomeVisible = false
    @State private var hasTriggeredAnimation = false

    let item: MenuItem

    init(item: MenuItem) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                item.icon
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .padding(.vertical, 4)
                    .foregroundColor(isHighlighted ? ColorProvider.SidebarIconNorm : ColorProvider.SidebarIconWeak)

                Text(item.text)
                    .font(.body.weight(isHighlighted ? .semibold : .regular))
                    .foregroundColor( item.textColor ?? ColorProvider.SidebarTextNorm)
                    .accessibilityIdentifier(item.identifier)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .onVisible {
            hasBecomeVisible = true
            tryStartAnimation()
        }
        .onChange(of: isPulseEnabled) { _ in
            tryStartAnimation()
        }
        .if(hasTriggeredAnimation) {
            $0.pulseOnce(duration: 1.2, repeatCount: 2)
        }
    }

    private func tryStartAnimation() {
        if isPulseEnabled && hasBecomeVisible && !hasTriggeredAnimation {
            hasTriggeredAnimation = true
        }
    }
}

// MARK: - Highlight Modifier
private struct IsHighlightedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isHighlighted: Bool {
        get { self[IsHighlightedKey.self] }
        set { self[IsHighlightedKey.self] = newValue }
    }
}

private struct MenuCellHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    func body(content: Content) -> some View {
        content.environment(\.isHighlighted, isHighlighted)
    }
}

extension View {
    func menuCellHighlighted(_ highlighted: Bool) -> some View {
        self.modifier(MenuCellHighlightModifier(isHighlighted: highlighted))
    }
}

// MARK: - Pulsating Animation Modifier
private struct HasPulseAnimationKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var hasPulseAnimation: Bool {
        get { self[HasPulseAnimationKey.self] }
        set { self[HasPulseAnimationKey.self] = newValue }
    }
}

extension View {
    func menuCellHasFadeAnimation(_ enabled: Bool) -> some View {
        environment(\.hasPulseAnimation, enabled)
    }
}
