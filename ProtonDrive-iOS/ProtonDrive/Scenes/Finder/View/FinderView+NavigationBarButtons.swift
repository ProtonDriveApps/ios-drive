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

extension FinderView {
    @ViewBuilder
    func leadingBarButtons(_ items: [NavigationBarButton]) -> some View {
        ForEach(items, content: navigationBarButton)
    }

    @ViewBuilder
    func trailingBarButtons(_ items: [NavigationBarButton]) -> some View {
        ForEach(items, content: navigationBarButton)
    }

    func editSectionMenuItems(environment: EditSectionEnvironment) -> [ContextMenuItem] {
        guard let node = vm.node else {
            return []
        }
        let nodeRowActionViewModel = NodeRowActionMenuViewModel(node: node, model: vm, isNavigationMenu: true)
        return nodeRowActionViewModel.editSection(environment: environment).items
    }

    func uploadSectionMenuViewItems(environment: EditSectionEnvironment) -> [ContextMenuItem] {
        guard let node = vm.node else {
            return []
        }
        let nodeRowActionViewModel = NodeRowActionMenuViewModel(node: node, model: vm, isNavigationMenu: true)
        return nodeRowActionViewModel.uploadSection(environment: environment).items
    }

    @ViewBuilder
    private func navigationBarButton(_ item: NavigationBarButton) -> some View {
        switch item {
        case .menu:
            MenuButton { NotificationCenter.default.post(.toggleSideMenu) }.any()

        case .upload where self.vm.node != nil:
            let uploadSectionItems = uploadSectionMenuViewItems(environment: .init(menuItem: $menuItem, modal: presentModal, sheet: $presentedSheet, acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage))
            ContextMenuView(icon: IconProvider.plus, viewModifier: ContextMenuNavigationModifier()) {
                ForEach(uploadSectionItems) { item in
                    ContextMenuItemActionView(item: item)
                }
            }
            .accessibility(identifier: "RoundButtonView.Button.Plus_Button")

        case .action where self.vm.node != nil:
            let environment = EditSectionEnvironment(menuItem: $menuItem, modal: presentModal, sheet: $presentedSheet, acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage)
            ContextMenuView(icon: IconProvider.threeDotsHorizontal, viewModifier: ContextMenuNavigationModifier()) {
                ForEach(uploadSectionMenuViewItems(environment: environment)) { item in
                    ContextMenuItemActionView(item: item)
                }
                Divider()
                ForEach(editSectionMenuItems(environment: environment)) { item in
                    ContextMenuItemActionView(item: item)
                }
            }
            .accessibility(identifier: "ContextMenuView.Button.Three_Dots_Horizontal")

        case let .apply(title, disabledInCurrentContext):
            TextNavigationBarButton(title: title)
            { [weak vm, weak root] in
                vm?.applyAction {
                    root?.closeCurrentSheet.send()
                }
            }
            .accessibility(identifier: "FinderView.NavigationBarButton.TextButton.RightActionButton")
            .disabled(vm.isUpdating || disabledInCurrentContext)

        case .close:
            SimpleCloseButtonView {
                presentationMode.wrappedValue.dismiss()
            }

        case .cancel:
            TextNavigationBarButton(title: "Cancel", weight: .bold) { [weak vm] in
                (vm as? (any HasMultipleSelection))?.cancelSelection()
            }
            .fixedSize()

        default:
            AssertionView("Unsupported NavigationBarButton requested")
        }
    }
}

struct ContextMenuNavigationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical)
            .padding(.trailing, -4)
    }
}
