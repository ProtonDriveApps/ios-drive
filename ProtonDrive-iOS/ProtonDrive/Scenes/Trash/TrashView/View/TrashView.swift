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
import PDCore
import ProtonCoreUIFoundations
import PDUIComponents

enum TrashMenu {
    case confirmation(on: NodeOperationType, action: () -> Void)
}

extension TrashMenu: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}

struct TrashView: View {
    @StateObject var vm: TrashViewModel
    @Environment(\.presentationMode) var presentationMode
    @State var menuItem: TrashMenu?
    
    var body: some View {
        ZStack {
            trashView
                .flatNavigationBar(
                    vm.nodeName,
                    leading: leadingBarButtons(vm.leadingNavBarItems),
                    trailing: trailingBarButtons(vm.trailingNavBarItems)
                )
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
        .onAppear(perform: vm.refreshOnAppear)
        .errorToast(location: .bottom, errors: vm.genericErrors.stream)
        .dialogSheet(item: $menuItem, model: dialogSheetModel())
        .overlay(
            actionBar
                .disabled(vm.loading)
        )
    }

    var trashView: some View {
        VStack {
            if vm.permanentChildren.isEmpty && !vm.isUpdating {
                HStack {
                    Spacer()
                    EmptyFolderView(viewModel: .trash)
                    Spacer()
                }
            } else {
                GridOrList(vm: vm) {
                    EmptyView()
                } contents2: {
                    ForEach(vm.permanentChildren) { nodeWrapper in
                        let svm = vm.prepareSelectionModel()
                        let nodeRowViewModel = NodeRowActionMenuViewModel(node: nodeWrapper.node, model: vm)
                        let nodeVM = TrashCellViewModel(
                            node: nodeWrapper.node,
                            selectionModel: svm,
                            nodeRowActionMenuViewModel: nodeRowViewModel,
                            featureFlagsController: vm.featureFlagsController
                        )
                        let cvm = addAction(to: nodeVM, menuItem: $menuItem)

                        Button(action: {}, label: {
                            FinderListCell(
                                vm: cvm,
                                presentedModal: .constant(nil),
                                presentedSheet: .constant(nil),
                                menuItem: .constant(nil), 
                                index: -1,
                                onTap: nodeVM.onTap,
                                onLongPress: svm.onLongPress
                            )
                        })
                        .buttonStyle(CellButtonStyle(isEnabled: true, background: ColorProvider.BackgroundSecondary))
                    }
                }
            }
        }
    }

    @ViewBuilder
    var actionBar: some View {
        if vm.activelySelecting {
            ActionBar(onSelection: actionBarAction,
                      leadingItems: [.restoreMultiple],
                      trailingItems: [.deleteMultiple])
                .opacity(vm.selection.selected.isEmpty ? 0 : 1)
                .animation(.default)
                .transition(.move(edge: .bottom))
        }
    }

    private func dialogSheetModel() -> DialogSheetModel {
        guard let menuItem = menuItem else {
            return DialogSheetModel.placeholder
        }
        switch menuItem {
        case let .confirmation(type, action):
            return vm.makeTrashAlert(type: type, action: action)
        }
    }

    private func actionBarAction(_ tapped: ActionBarButtonViewModel?) {
        switch tapped {
        case .deleteMultiple:
            guard let selectedNodesType = vm.findNodesType(isAll: false) else { return }
            let selectedIDs = Array(vm.selection.selected)
            let type: NodeOperationType = .multiple(ids: selectedIDs, type: selectedNodesType)
            self.menuItem = .confirmation(on: type) { [weak vm = self.vm] in
                vm?.delete(nodes: selectedIDs) {
                    vm?.cancelSelection()
                }
            }
        case .restoreMultiple:
            vm.restore(nodes: Array(vm.selection.selected), completion: { [weak vm = self.vm] in
                vm?.cancelSelection()
            })
        default:
            assert(false, "Should not be possible")
        }
    }
}

extension TrashView {
    private func addAction(to cvm: TrashCellViewModel, menuItem: Binding<TrashMenu?>) -> TrashCellViewModel {
        let id = cvm.node.identifier
        let single = NodeOperationType.single(id: id, type: cvm.nodeType)
        cvm.restoreButtonAction = { vm.restore(nodes: [id], completion: {}) }
        cvm.actionButtonAction = {
            menuItem.wrappedValue = .confirmation(on: single) { vm.delete(nodes: [id], completion: {}) }
        }
        return cvm
    }

    @ViewBuilder
    func leadingBarButtons(_ items: [NavigationBarButton]) -> some View {
        HStack {
            ForEach(items, content: navigationBarButton)

            Spacer()
        }
    }

    @ViewBuilder
    func trailingBarButtons(_ items: [NavigationBarButton]) -> some View {
        ForEach(items, content: navigationBarButton)
    }

    @ViewBuilder
    private func navigationBarButton(_ item: NavigationBarButton) -> some View {
        switch item {
        case .action where !vm.permanentChildren.isEmpty:
            menuButton
            .accessibilityIdentifier("TrashView.NavigationBarButton.Three_Dots_Horizontal")
        case .menu:
            MenuButton(action: { NotificationCenter.default.post(.toggleSideMenu) })
        case let .apply(title, disabled):
            selectAll(title, disabled: disabled)
        case .cancel:
            TextNavigationBarButton.cancel(vm.cancelSelection)
        default:
            AssertionView("Unsupported NavigationBarButton requested")
        }
    }

    private func selectAll(_ title: String, disabled: Bool) -> some View {
        TextNavigationBarButton(
            title: title,
            action: { [weak vm] in vm?.selectAll() }
        )
        .disabled(disabled)
    }

    private var menuButton: some View {
        ContextMenuView(icon: IconProvider.threeDotsHorizontal, viewModifier: ContextMenuNavigationModifier()) {
            ForEach(menuButtonActionItems) { item in
                ContextMenuItemActionView(item: item)
            }
        }
    }

    private var menuButtonActionItems: [ContextMenuItem] {
        guard let type = vm.findNodesType(isAll: true) else { return [] }
        let ids = Array(vm.selection.selectable)
        return [
            ContextMenuItem(sectionItem: TrashSectionItem.restore(type: .all(ids: ids, type: type))) {
                vm.restore(nodes: ids, completion: {})
            },
            ContextMenuItem(sectionItem: TrashSectionItem.delete(type: .all(ids: ids, type: type)), role: .destructive) {
                let ids = Array(vm.selection.selectable)
                menuItem = .confirmation(on: .all(ids: ids, type: type)) { vm.emptyTrash(nodes: ids, completion: {}) }
            }
        ]
    }
}
