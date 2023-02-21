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
import ProtonCore_UIFoundations
import PDUIComponents
import Combine

enum GridCellConstants {
    public static let grid: CGFloat = 82
    public static let placeholder: CGFloat = 48
}

struct FinderGridCell<ViewModel: NodeCellConfiguration>: View where ViewModel: ObservableObject {
    let gridSize: CGFloat = GridCellConstants.grid
    let placeholderSize: CGFloat = GridCellConstants.placeholder

    @Environment(\.acknowledgedNotEnoughStorage) var acknowledgedNotEnoughStorage
    @ObservedObject var vm: ViewModel
    
    let onTap: () -> Void
    let onLongPress: () -> Void

    private let presentedModal: Binding<FinderCoordinator.Destination?>
    private let presentedSheet: Binding<FinderCoordinator.Destination?>
    private let menuItem: Binding<FinderMenu?>

    init(
        vm: ViewModel,
        presentedModal: Binding<FinderCoordinator.Destination?>,
        presentedSheet: Binding<FinderCoordinator.Destination?>,
        menuItem: Binding<FinderMenu?>,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) {
        self.vm = vm
        self.presentedModal = presentedModal
        self.presentedSheet = presentedSheet
        self.menuItem = menuItem
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    var body: some View {
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                ThumbnailImage(
                    vm: vm.thumbnailViewModel,
                    placeholder: {
                        Image(vm.iconName)
                            .resizable()
                            .frame(width: placeholderSize, height: placeholderSize)
                    },
                    thumbnail: { thumbnail in
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }
                )
                .frame(width: gridSize - 1, height: gridSize - 1)
                .cornerRadius(3)
                .clipped()
                .padding(1)
                .background(selectionBackground.cornerRadius(3.0))

                Text(vm.name)
                    .lineLimit(1)
                    .font(.footnote)
                    .truncationMode(.middle)
                    .frame(width: gridSize)
                    .padding(.bottom, 4)
                    .accessibility(identifier: "FinderGridCell.Text.\(vm.name)")
            }
            .onTapGesture(perform: onTap)
            .onLongPressGesture(perform: onLongPress)

            VStack {
                gridButton(for: vm.buttonState)
                    .frame(height: 24)
                    .animation(nil, value: false)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .accessibility(identifier: "FinderGridCell.GridButton.\(vm.name)")
            }

        }
        .accessibilityElement(children: .contain)
        .background(ColorProvider.BackgroundNorm)
        .disabled(vm.isDisabled)
        .opacity(vm.isDisabled ? 0.5 : 1.0)
    }

    @ViewBuilder
    func gridButton(for state: GridButtonState) -> some View {
        let environment = EditSectionEnvironment(
            menuItem: menuItem,
            modal: presentedModal,
            sheet: presentedSheet,
            acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage
        )
        switch state {
        case .menu(let button):
            if let rowModel = vm.nodeRowActionMenuViewModel {
                switch button.type {
                case .menu where vm.nodeType == .file:
                    ContextMenuView(icon: button.icon, viewModifier: ContextMenuGridModifier()) {
                        editSectionView(items: rowModel.editSection(environment: environment).items)
                        Divider()
                        ForEach(rowModel.moreSection(environment: environment).items) { item in
                            ContextMenuItemActionView(item: item)
                        }
                    }
                    .accessibility(identifier: "NodeCell.ButtonView.\(vm.name)")
                case .menu where vm.nodeType == .folder:
                    ContextMenuView(icon: button.icon, viewModifier: ContextMenuGridModifier()) {
                        editSectionView(items: rowModel.editSection(environment: environment).items)
                    }
                    .accessibility(identifier: "NodeCell.ButtonView.\(vm.name)")
                default:
                    Button(action: button.action, label: {
                        button.icon
                            .accentColor(ColorProvider.TextNorm)
                    })
                    .accessibility(identifier: "NodeCell.ButtonView.\(vm.name)")
                }
            } else {
                Button(action: button.action, label: {
                    button.icon
                        .accentColor(ColorProvider.TextNorm)
                })
                .accessibility(identifier: "NodeCell.ButtonView.\(vm.name)")
            }

        case .selection(let isSelected):
            SelectionButton(isSelected: isSelected)
                .onTapGesture(perform: onTap)
                .accessibility(identifier: "selectionButton.\(vm.name)")
                .modifier(SelectionAnimationModifier(isSelected: vm.isSelected))

        case .downloading(let progress):
            HStack {
                Text(progress)
                    .font(.caption)
                    .foregroundColor(ColorProvider.TextWeak)

                ProtonSpinner(size: .small)
            }
            .frame(width: 100, height: 24)

        case .simple:
            EmptyView()

        }
    }

    var selectionBackground: some View {
        vm.isSelecting ? (vm.isSelected ? ColorProvider.Shade20 : Color.clear) : Color.clear
    }

    @ViewBuilder
    private func editSectionView(items: [ContextMenuItem]) -> some View {
        ForEach(items) { item in
            ContextMenuItemActionView(item: item)
        }
    }

}

extension NodeCellButton {
    var icon: Image {
        switch type {
        case .menu, .trash:
            return IconProvider.threeDotsHorizontal
        case .retry:
            return IconProvider.arrowRotateRight
        case .cancel:
            return IconProvider.cross
        }
    }
    
    var identifier: String {
        switch type {
        case .menu, .trash:
            return "NodeCellButton.three-dots-horizontal"
        case .retry:
            return "NodeCellButton.retry"
        case .cancel:
            return "NodeCellButton.cancel"
        }
    }
}

private struct ContextMenuGridModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical)
            .padding(.horizontal, 20)
    }
}
