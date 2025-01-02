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
import PDUIComponents
import Combine

enum GridCellConstants {
    public static let gridCellSize: CGSize = .init(width: 88, height: 132)
    public static let thumbnailSize: CGSize = .init(width: 80, height: 64)
    public static let placeholder: CGFloat = 48
}

struct FinderGridCell<ViewModel: NodeCellConfiguration>: View where ViewModel: ObservableObject {
    let placeholderSize: CGFloat = GridCellConstants.placeholder

    @Environment(\.acknowledgedNotEnoughStorage) var acknowledgedNotEnoughStorage
    @ObservedObject var vm: ViewModel
    
    let onTap: () -> Void
    let onLongPress: () -> Void

    private let presentedModal: Binding<FinderCoordinator.Destination?>
    private let presentedSheet: Binding<FinderCoordinator.Destination?>
    private let menuItem: Binding<FinderMenu?>
    private let index: Int

    init(
        vm: ViewModel,
        presentedModal: Binding<FinderCoordinator.Destination?>,
        presentedSheet: Binding<FinderCoordinator.Destination?>,
        menuItem: Binding<FinderMenu?>,
        index: Int,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) {
        self.vm = vm
        self.index = index
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
                            .allowsHitTesting(false)
                    }
                )
                .frame(width: GridCellConstants.thumbnailSize.width, height: GridCellConstants.thumbnailSize.height)
                .accessibilityIdentifier("thumbnail.\(vm.name)")
                .clipped()
                .cornerRadius(8)
                .padding(1)

                Text(vm.name)
                    .lineLimit(1)
                    .font(.footnote)
                    .truncationMode(.middle)
                    .frame(width: GridCellConstants.thumbnailSize.width)
                    .padding(.bottom, 4)
                    .accessibility(identifier: "FinderGridCell.Text.\(vm.name)")
                    .accessibilityLabel("\(vm.name)_\(index)")
            }
            .contentShape(Rectangle())
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
        .disabled(vm.isDisabled)
        .opacity(vm.isDisabled ? 0.5 : 1.0)
        .frame(width: GridCellConstants.gridCellSize.width, height: GridCellConstants.gridCellSize.height)
        .background(selectionBackground.cornerRadius(8))
    }

    @ViewBuilder
    func gridButton(for state: GridButtonState) -> some View {
        let environment = EditSectionEnvironment(
            menuItem: menuItem,
            modal: presentedModal,
            sheet: presentedSheet,
            acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage, 
            featureFlagsController: vm.featureFlagsController
        )
        switch state {
        case .menu(let button):
            if let rowModel = vm.nodeRowActionMenuViewModel {
                switch button.type {
                case .menu where vm.nodeType == .file:
                    ContextMenuView(icon: button.icon, viewModifier: ContextMenuGridModifier()) {
                        ForEach(rowModel.editSections(environment: environment)) { group in
                            editSectionView(items: group.items)
                            Divider()
                        }
                        ForEach(rowModel.moreSection(environment: environment).items) { item in
                            ContextMenuItemActionView(item: item)
                        }
                    }
                    .accessibility(identifier: "NodeCell.ButtonView.\(vm.name)")
                case .menu where vm.nodeType == .folder:
                    ContextMenuView(icon: button.icon, viewModifier: ContextMenuGridModifier()) {
                        ForEach(rowModel.editSections(environment: environment)) { group in
                            editSectionView(items: group.items)
                            Divider()
                        }
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
            RoundedSelectionView(isSelected: isSelected)
                .onTapGesture(perform: onTap)
                .accessibility(identifier: "selectionButton.\(vm.name)")
                .accessibilityLabel(vm.isSelected ? "selected" : "unselected")
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
        vm.isSelected ? ColorProvider.BackgroundSecondary : ColorProvider.BackgroundNorm
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
        HStack {
            Spacer()
            content
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .contentShape(Rectangle()) // Together with vertical padding above makes the tappable area bigger
    }
}
