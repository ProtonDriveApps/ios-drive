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

#if os(iOS)
struct ActionBarButtonView<ContextMenu: View>: View {
    var vm: ActionBarButtonViewModel
    @Binding var selection: ActionBarButtonViewModel?
    var contextMenu: ((ActionBarButtonViewModel) -> ContextMenu)?

    var body: some View {
        if vm.isContextMenu {
            Menu {
                contextMenu?(vm)
            } label: {
                actionLabel
            }
            .accessibility(identifier: self.vm.accessibilityIdentifier)
        } else {
            actionItemView
        }
    }

    private var actionItemView: some View {
        Button {
            withAnimation {
                self.selection = self.vm
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            }
        } label: {
            actionLabel
        }
        .accessibility(identifier: self.vm.accessibilityIdentifier)
    }

    private var actionLabel: some View {
        HStack(alignment: .center) {
            if let icon = self.vm.icon {
                image(for: icon)
            }

            if self.vm.title != nil, vm.showTitle {
                Text(self.vm.title!)
                    .font(vm.isBold ? .body.bold() : .body)
                    .foregroundColor(ColorProvider.BrandNorm)
                    .frame(minHeight: ActionBarSize.height, alignment: .top)
            }
        }
        .padding(.horizontal, self.vm.title != nil ? 12 : 8)
    }

    var actionBarIndicator: some View {
        Circle()
            .fill(ColorProvider.FloatyPressed)
            .blendMode(.lighten) // chooses the lighest color for resulting pixel, so will let the white icon be visible
    }

    private func image(for icon: Image) -> some View {
        icon
            .resizable()
            .frame(width: 20, height: 20, alignment: .top)
            .foregroundColor(ColorProvider.IconNorm)
            .background(
                actionBarIndicator
                    .opacity(vm.isAutoHighlighted ? 1.0 : 0.0)
            )
    }
}
#endif
