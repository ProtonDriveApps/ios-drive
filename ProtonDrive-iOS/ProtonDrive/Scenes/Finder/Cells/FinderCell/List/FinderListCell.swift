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

import PDCore
import SwiftUI
import PDUIComponents
import ProtonCoreUIFoundations

private let horizontalInset: CGFloat = 16

struct FinderListCell<ViewModel: NodeCellConfiguration>: View where ViewModel: ObservableObject {
    @Environment(\.acknowledgedNotEnoughStorage) var acknowledgedNotEnoughStorage
    @ObservedObject var vm: ViewModel

    let onTap: () -> Void
    let onLongPress: () -> Void

    private let presentedModal: Binding<FinderCoordinator.Destination?>
    private let presentedSheet: Binding<FinderCoordinator.Destination?>
    private let menuItem: Binding<FinderMenu?>
    private let index: Int

    init(vm: ViewModel,
         presentedModal: Binding<FinderCoordinator.Destination?>,
         presentedSheet: Binding<FinderCoordinator.Destination?>,
         menuItem: Binding<FinderMenu?>,
         index: Int,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void) {
        self.vm = vm
        self.index = index
        self.presentedModal = presentedModal
        self.presentedSheet = presentedSheet
        self.menuItem = menuItem
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if hasHorizontalPadding {
                cellContent
                    .padding(.horizontal)
            } else {
                cellContent
                    .padding(.leading, horizontalInset)
            }

            separator
        }
        .frame(height: 74)
        .background(ColorProvider.BackgroundNorm)
        .disabled(vm.isDisabled)
        .opacity(vm.isDisabled ? 0.5 : 1.0)
    }

    var hasHorizontalPadding: Bool {
        vm.uploadPaused || vm.uploadFailed || vm.isSelecting || (vm is TrashCellViewModel) || vm.uploadWaiting
    }
    
    var cellContent: some View {
        HStack {
            
            HStack {
                icon()
                    .frame(width: 40, height: 40)

                VStack(spacing: 0) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.name)
                            .truncationMode(vm.nodeType == .file ? .middle : .tail)
                            .foregroundColor(ColorProvider.TextNorm)
                            .lineLimit(1)
                            .accessibility(identifier: "NodeCell.Text.\(vm.name)")
                            .accessibilityLabel("\(vm.name)_\(index)")

                        HStack(spacing: 0) {
                            NodeListSecondLineView(
                                vm: vm.secondLine,
                                parentIdentifier: "NodeListSecondLineView.\(vm.name)"
                            )
                            .accessibilityElement(children: .contain)
                            Spacer()
                        }

                    }

                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(perform: onLongPress)
            
            if !vm.isSelecting {
                actions
                    .padding(.leading)
            }
        }
    }
}

// MARK: - Leading Icon and Trailing Button
private extension FinderListCell {
    @ViewBuilder
    func icon() -> some View {
        if vm.isSelecting {
            SelectionButton(isSelected: vm.isSelected)
                .transition(.asymmetric(insertion: .slide, removal: .identity))
                .accessibility(identifier: "selectionButton.\(vm.name)")
                .modifier(SelectionAnimationModifier(isSelected: vm.isSelected))
        } else {
            ThumbnailImage(vm: vm.thumbnailViewModel) {
                Image(vm.iconName)
                    .resizable()
                    .frame(width: 40, height: 40, alignment: .leading)
            } thumbnail: { thumbnail in
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
            }
            .frame(width: 40)
            .transition(.asymmetric(insertion: .slide, removal: .identity))
        }
    }

    private func defaultCellButton(_ button: NodeCellButton) -> some View {
        Button(action: button.action, label: {
            button.icon
                .accentColor(ColorProvider.TextNorm)
                .frame(width: 40, height: 40, alignment: .trailing)
        })
    }

    @ViewBuilder
    func uploadManagementMenuButton(_ file: File, model: UploadManagementMenuViewModel) -> some View {
        ContextMenuView(icon: IconProvider.threeDotsHorizontal, viewModifier: ContextMenuListModifier()) {
            ForEach(model.uploadManagementSection(file: file).items) { item in
                ContextMenuItemActionView(item: item)
            }
        }
        .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(vm.name)")
    }

    @ViewBuilder
    func cellRowForButton(_ button: NodeCellButton, model: NodeRowActionMenuViewModel, environment: EditSectionEnvironment) -> some View {
        switch button.type {
        case .menu where vm.nodeType == .file:
            ContextMenuView(icon: button.icon, viewModifier: ContextMenuListModifier()) {
                primarySectionView(items: model.editSection(environment: environment).items)
                Divider()
                ForEach(model.moreSection(environment: environment).items) { item in
                    ContextMenuItemActionView(item: item)
                }
            }
            .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(vm.name)")
        case .menu where vm.nodeType == .folder:
            ContextMenuView(icon: button.icon, viewModifier: ContextMenuListModifier()) {
                primarySectionView(items: model.editSection(environment: environment).items)
            }
            .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(vm.name)")
        case .cancel:
            defaultCellButton(button)
                .accessibility(identifier: "NodeCellButton.cancel.\(vm.name)")
        case .retry:
            defaultCellButton(button)
                .accessibility(identifier: "NodeCellButton.retry.\(vm.name)")
        case .trash(let id):
                let type = NodeOperationType.single(id: id, type: vm.nodeType)
            ContextMenuView(icon: button.icon, viewModifier: ContextMenuTrashModifier()) {
                primarySectionView(items: trashSectionItems(type: type))
            }
            .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(vm.name)")
        default:
            defaultCellButton(button)
                .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(vm.name)")
        }
    }

    private func trashSectionItems(type: NodeOperationType) -> [ContextMenuItem] {
        guard let vm = vm as? TrashCellViewModel else { return [] }
        return [
            vm.restoreRow(
                type: type,
                action: { [weak vm] in vm?.restoreButtonAction() }
            ),
            vm.deleteRow(
                type: type,
                action: { [weak vm] in vm?.actionButtonAction() }
            )
        ]
    }

    @ViewBuilder
    private func primarySectionView(items: [ContextMenuItem]) -> some View {
        ForEach(items) { item in
            ContextMenuItemActionView(item: item)
        }
    }

    private func moreSectionView(items: [ContextMenuItem]) -> some View {
        ForEach(items) { item in
            ContextMenuItemActionView(item: item)
                .accessibility(identifier: "ContextMenuItemActionView.\(item.identifier)")
        }
    }

    @ViewBuilder
    var actions: some View {
        let environment = EditSectionEnvironment(
            menuItem: menuItem,
            modal: presentedModal,
            sheet: presentedSheet,
            acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage
        )
        HStack(spacing: 0) {
            if let vm = vm as? NodeCellWithProgressConfiguration,
               let model = vm.uploadManagementMenuViewModel,
               let file = model.node as? File,
               vm.isInProgress,
               vm.progressDirection == .upstream {
                uploadManagementMenuButton(file, model: model)
            } else {
                ForEach(vm.buttons, id: \.type) { button in
                    if let actionMenu = vm.nodeRowActionMenuViewModel {
                        cellRowForButton(button, model: actionMenu, environment: environment)
                    } else {
                        defaultCellButton(button)
                            .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(vm.name)")
                    }
                }
            }
        }
    }
}

// MARK: - Separation
private extension FinderListCell {
    var separator: some View {
        Group {
            switch vm.separator {
            case .divider:
                Spacer()
                    .frame(height: 1.0)

            case .progressing(let progress):
                ProgressBar(
                    value: .init(get: { progress }, set: { _ in }),
                    offset: 0,
                    foregroundColor: ColorProvider.BrandNorm,
                    backgroundColor: ColorProvider.SeparatorNorm)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1.0)
                    .accessibility(identifier: "ProgressBar.uploadingOrDownloading")
            }
        }
    }
}

private struct ContextMenuListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical)
            .padding(.horizontal, horizontalInset)
    }
}

private struct ContextMenuTrashModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical)
            .padding(.leading, horizontalInset)
    }
}
