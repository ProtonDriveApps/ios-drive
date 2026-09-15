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
import PDUIComponents

struct ComputerCellView: View {
    @ObservedObject var viewModel: ComputerCellViewModel
    @State private var isPressed = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isPressed ? ColorProvider.BackgroundSecondary : ColorProvider.BackgroundNorm)

            HStack(spacing: 16) {
                HStack {

                    Image(getIconName())
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(ColorProvider.TextNorm)

                    Text(getDisplayName())
                        .font(.body)
                        .foregroundColor(ColorProvider.TextNorm)
                        .accessibilityIdentifier("ComputerCellView.Button.\(getDisplayName())")

                    Spacer()
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // As soon as user touches down, highlight the row
                            isPressed = true
                        }
                        .onEnded { _ in
                            // On finger lift, remove highlight and do the action
                            isPressed = false
                            viewModel.cellTapped()
                        }
                )

                ContextMenuView(
                    icon: IconProvider.threeDotsHorizontal,
                    viewModifier: EmptyModifier()
                ) {
                    ForEach(viewModel.getContextMenuItems().items) { group in
                        ForEach(group.items) { item in
                            ContextMenuItemActionView(item: item)
                        }
                        Divider()
                    }
                }
                .accessibility(identifier: "ComputerCellView.three-dots-horizontal.\(getDisplayName())")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .redacted(reason: isLoading() ? .placeholder : [])
    }

    private func getIconName() -> String {
        switch viewModel.viewState.state {
        case .loading:
            return "ic-tv"
        case .loaded(_, let iconName):
            return iconName
        }
    }

    private func getDisplayName() -> String {
        switch viewModel.viewState.state {
        case .loading:
            return "Loading..."
        case .loaded(let name, _):
            return name
        }
    }

    private func isLoading() -> Bool {
        if case .loading = viewModel.viewState.state {
            return true
        }
        return false
    }
}
