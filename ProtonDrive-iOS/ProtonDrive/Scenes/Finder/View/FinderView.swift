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

struct FinderView<ViewModel: ObservableFinderViewModel>: View {
    @Environment(\.acknowledgedNotEnoughStorage) var acknowledgedNotEnoughStorage
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode

    @EnvironmentObject var root: RootViewModel

    @ObservedObject var vm: ViewModel
    @ObservedObject var coordinator: FinderCoordinator

    @State var headersShadowVisible1: Bool = false
    @State var headersShadowVisible2: Bool = false
    @State var menuItem: FinderMenu?
    @State var errorsWithToast = ErrorToastModifier.Stream()
    @State var presentedSheet: (FinderCoordinator.Destination)?

    var presentModal: Binding<FinderCoordinator.Destination?>
    var drilldownTo: Binding<Node.ID?>

    let errorToastSize: CGFloat = 56

    var body: some View {
        ZStack {
            VStack {
                if vm.lockedStateBannerVisibility != .hidden {
                    lockedStateBannerView
                }
                
                finderView
            }
            .flatNavigationBar(vm.nodeName,
                               delegate: vm,
                               leading: leadingBarButtons(vm.leadingNavBarItems),
                               trailing: trailingBarButtons(vm.trailingNavBarItems))
        }
        .navigationBarBackButtonHidden(multipleSelectionIsSelecting)
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
        .onAppear {
            // vm.isVisible is set by FinderCoordinator because this method is called unreliably for Grid
            root.stateRestorationActivity = coordinator.buildStateRestorationActivity()
        }
        .errorToast(location: .bottomWithOffset(errorToastSize), errors: errorsWithToast)
        .presentView(item: $presentedSheet, style: .sheet) {
            self.coordinator.go(to: $0).environmentObject(root).environmentObject(TabBarViewModel())
        }
        .presentView(item: presentModal, style: .fullScreenWithBlender) {
            self.coordinator.go(to: $0).environmentObject(root).environmentObject(TabBarViewModel())
        }
        .dialogSheet(item: $menuItem, model: dialogSheetModel())
        .onReceive(root.closeCurrentSheet) { _ in
            presentedSheet = nil
            presentModal.wrappedValue = nil
        }
        .onReceive(vm.genericErrors.stream.replaceError(with: nil)) {
            reactToError(FinderError($0))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if vm.isVisible {
                vm.refreshOnAppear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DriveCoordinator.LogoutNotification"))) { _ in
            (vm as? DownloadingViewModel)?.childrenDownloadCancellable?.cancel()
            (vm as? DownloadingViewModel)?.childrenDownloadCancellable = nil
        }
        .modifier(HeaderScrollObserver<GridOrListSection1OffsetPreferenceKey>(visible: $headersShadowVisible1))
        .modifier(HeaderScrollObserver<GridOrListSection2OffsetPreferenceKey>(visible: $headersShadowVisible2))
    }

    @ViewBuilder var finderView: some View {
        ZStack {
            GridOrList(vm: vm) {
                if !vm.transientChildren.isEmpty {
                    Section(header: uploadingBar, footer: Spacer(minLength: 30)) {
                        uploadDisclaimer
                        ForEach(vm.transientChildren.indices, id: \.self) { index in
                            nodeRow(vm.transientChildren[index], isList: true, index: index)
                        }
                    }
                }
            } contents2: {
                if !vm.permanentChildren.isEmpty {
                    Section(header: listHeader, footer: listFooter) {
                        ForEach(vm.permanentChildren.indices, id: \.self) { index in
                            nodeRow(vm.permanentChildren[index], isList: vm.layout == .list, index: index)
                        }
                    }
                }
            }

            if vm.needsNoConnectionBackground {
                NoConnectionFolderView(isUpdating: $vm.isUpdating, refresh: vm.refreshOnAppear)
            }

            if vm.emptyBackgroundConfig != nil {
                EmptyFolderView(viewModel: vm.emptyBackgroundConfig!)
                    .opacity(vm.provedEmpty ? 1 : 0)
            }

            if vm is UploadingViewModel {
                VStack {
                    Spacer()

                    uploadsErrorToast
                }
            }

            if multipleSelectionIsSelecting {
                multipleSelectionActionBar
            }
        }
    }
    
    @ViewBuilder var lockedStateBannerView: some View {
        if vm.lockedStateBannerVisibility != .hidden {
            let lockedStateVM = LockedStateTopBannerViewModel(lockedStateBannerVisibiliy: vm.lockedStateBannerVisibility)
            LockedStateTopBannerView(viewModel: lockedStateVM)
        }
    }
    
    @ViewBuilder private var uploadDisclaimer: some View {
        if vm.isUploadDisclaimerVisible {
            NotificationBanner(
                message: "For uninterrupted uploads, keep the app open. Uploads will pause when the app is in the background.",
                style: .inverted,
                padding: .vertical,
                closeBlock: vm.closeUploadDisclaimer
            )
        }
    }

    private func nodeRow(_ node: NodeWrapper, isList: Bool, index: Int) -> some View {
        FinderCell<ViewModel>(
            node: node.node,
            finderViewModel: vm,
            deeplink: drilldownTo,
            presentedModal: presentModal,
            presentedSheet: $presentedSheet,
            menuItem: $menuItem,
            isList: isList,
            index: index
        )
        .environmentObject(coordinator)
    }
    
    @ViewBuilder private var listHeader: some View {
        if vm.supportsLayoutSwitch || vm.supportsSortingSwitch {
            FinderConfigurationView(
                sortingText: vm.permanentChildrenSectionTitle,
                switchSorting: vm.supportsSortingSwitch ? { newSorting in vm.switchSorting(newSorting) } : nil,
                sorting: vm.sorting,
                layout: vm.layout,
                changeLayout: vm.supportsLayoutSwitch ? vm.changeLayout : nil
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .modifier(HeaderShadowModifier(visible: $headersShadowVisible2))
        }
    }

    @ViewBuilder private var uploadingBar: some View {
        UploadingSectionHeader(title: "Uploading")
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .padding(.vertical, 8)
        .modifier(HeaderShadowModifier(visible: $headersShadowVisible1))
    }
    
    private var listFooter: some View {
        NodesListFooter(text: "")
            .onAppear(perform: self.vm.didScrollToBottom)
    }

    private func dialogSheetModel() -> DialogSheetModel {
        guard let menuItem = menuItem else {
            return DialogSheetModel.placeholder
        }

        switch menuItem {
        case let .trash(nodeVM, isNavigationMenu):
            return nodeVM.makeTrashAlert(environment: .init(menuItem: $menuItem, presentationMode: isNavigationMenu ? presentationMode : nil, cancelSelection: (vm as? (any HasMultipleSelection))?.cancelSelection))
        }
    }

    @ViewBuilder private var uploadsErrorToast: some View {
        if self.vm is UploadingViewModel
            && (self.vm as! UploadingViewModel).showsUploadsErrorBanner
            && self.vm.isVisible
        {
            ProgressesStatusToast(uploadErrors: (self.vm as! UploadingViewModel).uploadErrors,
                                  failedUploads: (self.vm as! UploadingViewModel).failedCount)
                .transition(.move(edge: .bottom))
                .padding(.bottom, errorToastSize)
                .padding(.horizontal)
        } else {
            EmptyView()
        }
    }

    private var multipleSelectionIsSelecting: Bool {
        guard let vm = vm as? (any HasMultipleSelection) else {
            return false
        }
        return vm.listState.isSelecting
    }
    
    private func reactToError(_ error: FinderError) {
        switch error {
        case .noSpaceOnDevice where self.acknowledgedNotEnoughStorage.wrappedValue != true:
            self.presentedSheet = .noSpaceLeftLocally
        case .noSpaceOnCloud:
            self.presentedSheet = .noSpaceLeftCloud
        case .toast(error: let toastError):
            self.errorsWithToast.send(toastError)
        default:
            break
        }
    }
    
    @ViewBuilder private var multipleSelectionActionBar: some View {
        if let selectionViewModel = vm as? FinderViewModelWithSelection, selectionViewModel.listState.isSelecting {
            ActionBar(
                onSelection: { selectionViewModel.actionBarAction($0, sheet: self.$presentedSheet, menuItem: self.$menuItem) },
                items: selectionViewModel.actionBarItems(),
                content: {
                    if selectionViewModel.selection.selected.count == 1 {
                        contextMenuView(selectionViewModel: selectionViewModel)
                    } else {
                        EmptyView()
                    }
                }
            )
            .animation(.default)
            .opacity(selectionViewModel.selection.selected.isEmpty ? 0 : 1)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func contextMenuView(selectionViewModel: FinderViewModelWithSelection) -> some View {
        let editSectionEnvironment = EditSectionEnvironment(menuItem: $menuItem, modal: presentModal, sheet: $presentedSheet, acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage)
        let nodes = selectionViewModel.selectedNodes()
        if let node = nodes.map(\.node).first {
            let nodeRowViewModel = NodeRowActionMenuViewModel(node: node, model: vm)

            ContextMenuView(icon: IconProvider.threeDotsHorizontal, color: ColorProvider.IconNorm, viewModifier: EmptyModifier()) {
                ForEach(nodeRowViewModel.editSection(environment: editSectionEnvironment).items) { item in
                    ContextMenuItemActionView(item: item)
                        .accessibility(identifier: "ContextMenuItemActionView.\(item.identifier)")
                }
                if node is File {
                    Divider()
                    ForEach(nodeRowViewModel.moreSection(environment: editSectionEnvironment).items) { item in
                        ContextMenuItemActionView(item: item)
                            .accessibility(identifier: item.identifier)
                    }
                }
            }
            .frame(width: 20, height: 20)
            .accessibility(identifier: "ActionBar.Button.MoreSingle")
        }

    }

}
