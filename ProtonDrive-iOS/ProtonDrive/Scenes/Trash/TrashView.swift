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
import PMUIFoundations

enum TrashMenuOrigin {
    case row
    case navigation
}

enum TrashMenu {
    case action(type: NodeDeletionType, from: TrashMenuOrigin)
    case confirmation(environment: TrashViewEnvironment, action: () -> Void)
}

extension TrashMenu: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}

struct TrashView: View {
    @ObservedObject var vm: TrashViewModel
    @ObservedObject var coordinator: TrashViewCoordinator
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State var menuItem: TrashMenu?

    var body: some View {
        ZStack {
            List {
                if self.vm.state == .initial {
                    Spacer()
                }

                if self.vm.state == .populated {
                    Section(footer: NodesListFooter()) {
                        ForEach(self.vm.trashedItems, id: \TrashCellViewModel.node) { nodeVM in
                            self.row(for: nodeVM)
                        }
                    }
                }
            }
            .hackSeparators()
            .pullToRefresh(isShowing: self.$vm.isRefreshing, onRefresh: { [weak vm = self.vm] in vm?.onRefresh() })
            .flatNavigationBar(vm.pageTitle,
                               colorScheme: colorScheme,
                               delegate: coordinator,
                               leadingItems: navigationBarButtons(vm.leadingNavBarItems),
                               trailingItems: navigationBarButtons(vm.trailingNavBarItems))
            .onAppear(perform: vm.onAppear)

            if self.vm.state == .empty {
                EmptyTrash()
            }
        }
        .background(BackgroundColors.Main.edgesIgnoringSafeArea(.all))
        .actionSheet(item: $menuItem, model: { item in
            switch item {
            case .action(let type, let origin):
                return vm.makeTrashMenu(environment: .init(menuItem: $menuItem, type: type, origin: origin))
            case .confirmation(environment: let environment, let action):
                return vm.makeTrashAlert(environment: environment, action: action)
            }
        })
        .errorToast(location: .bottom, errors: self.vm.genericErrors)
    }
}

extension TrashView {
    func navigationBarButtons(_ items: [NavigationBarButton]) -> AnyView? {
        if items.isEmpty {
            return nil
        } else {
            return HStack {
                ForEach(items, content: self.navigationBarButton)
            }.any()
        }
    }

    private func navigationBarButton(_ item: NavigationBarButton) -> some View {
        switch item {
        case .action:
            switch vm.state {
            case .populated:
                return ActionButton {
                    menuItem = .action(type: .all(count: vm.trashedItems.count, type: .mix), from: .navigation)
                }.any()
            default:
                return EmptyView().any()
            }
        case .close:
            return SimpleCloseButtonView {
                presentationMode.wrappedValue.dismiss()
            }.any()
        default:
            assert(false, "Unknown button requested")
            return EmptyView().any()
        }
    }

    private func row(for cvm: TrashCellViewModel) -> some View {
        let type = NodeDeletionType.single(id: cvm.nodeID, type: cvm.nodeType)
        cvm.actionButtonAction = {
            menuItem = .action(type: type, from: .row)
        }
        return ZStack {
            NodeCell(vm: cvm)
                .buttonStyle(PlainButtonStyle())
        }
            .padding(.vertical, -6) // will fix misplacement of selection overlay
            .listRowInsets(EdgeInsets.listRowInsets)
            .listRowBackground(BackgroundColors.Main)
            .animation(.none)
    }
}

extension EdgeInsets {
    static var listRowInsets: EdgeInsets? {
        if #available(iOS 14.0, *) {
            return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0)
        } else {
            return nil
        }
    }
}
