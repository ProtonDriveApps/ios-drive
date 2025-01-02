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
import Combine

struct FinderCell<ViewModel: ObservableFinderViewModel>: View {
    @Environment(\.acknowledgedNotEnoughStorage) var acknowledgedNotEnoughStorage
    @EnvironmentObject var coordinator: FinderCoordinator
    @EnvironmentObject var tabBar: TabBarViewViewModel
    @EnvironmentObject var root: RootViewModel

    @ObservedObject var node: Node
    @ObservedObject var finderViewModel: ViewModel

    private let deeplinkTo: Binding<String?>
    private let presentedModal: Binding<FinderCoordinator.Destination?>
    private let presentedSheet: Binding<FinderCoordinator.Destination?>
    private let menuItem: Binding<FinderMenu?>
    private let isList: Bool
    private let isEnabled: Bool
    private let index: Int

    init(
        node: Node,
        finderViewModel: ViewModel, deeplink: Binding<String?>,
        presentedModal: Binding<FinderCoordinator.Destination?>,
        presentedSheet: Binding<FinderCoordinator.Destination?>,
        menuItem: Binding<FinderMenu?>, isList: Bool, index: Int
    ) {
        self.node = node
        self.index = index
        self.finderViewModel = finderViewModel
        self.deeplinkTo = deeplink
        self.presentedModal = presentedModal
        self.presentedSheet = presentedSheet
        self.menuItem = menuItem
        self.isList = isList
        self.isEnabled = !finderViewModel.childViewModel(for: node).isDisabled
    }

    var body: some View {
        ZStack {
            Button(action: {}, label: {
                makeCellFor(node: node, isList: isList)
                    .accessibilityElement(children: .contain)
            })
            .buttonStyle(CellButtonStyle(isEnabled: isEnabled, background: ColorProvider.BackgroundSecondary))

            if destination != .none {
                navigationLink
                // Known issue in iOS 14.5 https://developer.apple.com/forums/thread/677333
                // https://forums.swift.org/t/14-5-beta3-navigationlink-unexpected-pop/45279
                // Adding an NavigationLink with empty label and destination fixes the issues in most cases.
                // In ProtonDrive, in particular, two of them are needed.
                if #available(iOS 14.5, *) {
                    NavigationLink(destination: EmptyView()) {
                        EmptyView()
                    }
                    NavigationLink(destination: EmptyView()) {
                        EmptyView()
                    }
                }
            }
        }
    }

    private var destination: FinderCoordinator.Destination {
        coordinator.destination(for: node)
    }

    private var navigationLink: some View {
        let nextView = LazyDrilldown(self.coordinator.go(to: destination))
            .environmentObject(root)

        /*
         iOS 14.0 has somehow different processing of selection in the NavigaionLink which does not allow to switch off animations and is animating couples of screens back-and-forth multiple times. Some betas were crashing, some did not complete the sequence. This NavigationLink is a workaround.

         Original radar: FB7840140
         */
        let binding = Binding(get: { self.deeplinkTo.wrappedValue == node.identifier.nodeID },
                              set: { if !$0 { self.deeplinkTo.wrappedValue = nil } })

        return NavigationLink(destination: nextView, isActive: binding) {
            EmptyView()
        }
    }

    @ViewBuilder
    func makeCellFor(node: Node, isList: Bool) -> some View {
        if isList {
            listCell(for: node)
        } else {
            gridCell(for: node)
        }
    }

    func listCell(for node: Node) -> some View {
        let vm = cellVM(for: node)
        switch vm {
        case let vm as NodeCellSimpleConfiguration:
            return FinderListCell(
                vm: vm,
                presentedModal: presentedModal,
                presentedSheet: presentedSheet,
                menuItem: menuItem,
                index: index,
                onTap: { [unowned vm] in
                    onCellTap(cellViewModel: vm)
                },
                onLongPress: { [weak vm] in
                    vm?.selectionModel?.onLongPress()
                }).any()
        case let vm as NodeCellWithProgressConfiguration:
            return FinderListCell(
                vm: vm,
                presentedModal: presentedModal,
                presentedSheet: presentedSheet,
                menuItem: menuItem,
                index: index,
                onTap: { [unowned vm] in
                    onCellTap(cellViewModel: vm)
                },
                onLongPress: { [weak vm] in
                    vm?.selectionModel?.onLongPress()
                }).any()
        default:
            let vm = NodeCellPlaceholderConfiguration(featureFlagsController: coordinator.featureFlagsController)
            return FinderListCell(
                vm: vm,
                presentedModal: presentedModal,
                presentedSheet: presentedSheet,
                menuItem: menuItem,
                index: index,
                onTap: { [unowned vm] in
                    onCellTap(cellViewModel: vm)
                },
                onLongPress: { [weak vm] in
                    vm?.selectionModel?.onLongPress()
                }).any()
        }
    }

    func gridCell(for node: Node) -> some View {
        let vm = cellVM(for: node)
        switch vm {
        case let vm as NodeCellSimpleConfiguration:
            return FinderGridCell(
                vm: vm,
                presentedModal: presentedModal,
                presentedSheet: presentedSheet,
                menuItem: menuItem,
                index: index,
                onTap: { [unowned vm] in
                    onCellTap(cellViewModel: vm)
                },
                onLongPress: { [weak vm] in
                    vm?.selectionModel?.onLongPress()
                }).any()
        case let vm as NodeCellWithProgressConfiguration:
            return FinderGridCell(
                vm: vm,
                presentedModal: presentedModal,
                presentedSheet: presentedSheet,
                menuItem: menuItem,
                index: index,
                onTap: { [unowned vm] in
                    onCellTap(cellViewModel: vm)
                },
                onLongPress: { [weak vm] in
                    vm?.selectionModel?.onLongPress()
                }).any()
        default:
            let vm = NodeCellPlaceholderConfiguration(featureFlagsController: coordinator.featureFlagsController)
            return FinderGridCell(
                vm: vm,
                presentedModal: presentedModal,
                presentedSheet: presentedSheet,
                menuItem: menuItem,
                index: index,
                onTap: { [unowned vm] in
                    onCellTap(cellViewModel: vm)
                },
                onLongPress: { [weak vm] in
                    vm?.selectionModel?.onLongPress()
                }).any()
        }
    }

    private func cellVM(for node: Node) -> NodeCellConfiguration {
        let cellViewModel = finderViewModel.childViewModel(for: node)

        switch cellViewModel {
        case let vm as NodeCellSimpleConfiguration:
            return vm

        case let vm as NodeCellWithProgressConfiguration:
            vm.nodeRowActionMenuViewModel = NodeRowActionMenuViewModel(node: node, model: finderViewModel)

            if let model = finderViewModel.model as? UploadsListing {
                vm.uploadManagementMenuViewModel = UploadManagementMenuViewModel(node: node, model: model)
            }

            vm.retryUploadAction = { [weak finderViewModel] in
                guard let uploads = finderViewModel?.model as? UploadsListing,
                      let file = node as? File  else { return }

                uploads.restartUpload(node: file)
            }

            vm.cancelUploadAction = { [weak finderViewModel] in
                guard let uploads = finderViewModel?.model as? UploadsListing,
                      let file = node as? File  else { return }

                uploads.cancelUpload(file: file)
            }
            return vm

        default:
            let vm = NodeCellPlaceholderConfiguration(featureFlagsController: coordinator.featureFlagsController)
            return vm
        }
    }

    private func onCellTap(cellViewModel: NodeCellConfiguration) {
        // This part is in charge of navigation and business logic that happen when user taps on the row.
        // There are three kinds of rows in this table: folder, file with only metadata, file with metadata and a downloaded revision
        // - tap on folder should cause a drilldown prowered by NavigationLink (if any)
        // - tap on a file without revision should invoke downloading of the revision
        // - tap on file with revision should navigate to presenter

        guard !cellViewModel.isSelecting else {
            cellViewModel.selectionModel?.onTap(id: cellViewModel.id)
            return
        }

        let destination = coordinator.destination(for: node)

        switch node {
        case is File where destination != .none:
            presentedModal.wrappedValue = destination

        case is File where destination == .none:
            // interaction with node row defaults the acknowledgement
            acknowledgedNotEnoughStorage.wrappedValue = false
            finderViewModel.download(node: node)

        case is Folder:
            deeplinkTo.wrappedValue = node.identifier.nodeID

        default:
            assert(false, "unknown cell type")
        }
    }
}
