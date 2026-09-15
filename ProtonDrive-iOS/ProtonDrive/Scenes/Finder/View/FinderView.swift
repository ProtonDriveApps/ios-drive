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
import PDCoreIOS
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

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

    private let invitationViewsFactory: PendingInvitationsListViewFactory?

    init(
        vm: ViewModel,
        coordinator: FinderCoordinator,
        presentModal: Binding<FinderCoordinator.Destination?>,
        drilldownTo: Binding<Node.ID?>,
        invitationViewsFactory: PendingInvitationsListViewFactory? = nil
    ) {
        self.vm = vm
        self.coordinator = coordinator
        self.presentModal = presentModal
        self.drilldownTo = drilldownTo
        self.invitationViewsFactory = invitationViewsFactory
    }

    var body: some View {
        ZStack {
            VStack {
                if vm.lockedStateBannerVisibility != .hidden {
                    lockedStateBannerView
                }

                // `shouldShowBanner` can be computed.
                // The app restarts when the lock status changes, so the value is correct when `FinderView` is rendered.
                if vm.isRoot && vm.currentTab == .files && coordinator.volumeLockController.shouldShowBanner {
                    VolumeLockBannerView(
                        controller: coordinator.volumeLockController,
                        tower: coordinator.tower,
                        authenticator: coordinator.authenticator
                    )
                }

                upgradeHintBanner
                finderView
            }
            .flatNavigationBar(
                vm.nodeName,
                leading: leadingBarButtons(vm.leadingNavBarItems),
                trailingItems: vm.trailingNavBarItems,
                trailingItem: navigationBarButton
            )
        }
        .navigationBarBackButtonHidden(multipleSelectionIsSelecting)
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
        .onAppear {
            // vm.isVisible is set by FinderCoordinator because this method is called unreliably for Grid
            root.stateRestorationActivity = coordinator.buildStateRestorationActivity()
            if vm.isRoot {
                coordinator.volumeLockController.resetBannerVisibilityForMyFilesAppear()
            }
        }
        .errorToast(location: .bottomWithOffset(12), errors: errorsWithToast)
        .presentView(item: $presentedSheet, style: .sheet) {
            self.coordinator.go(to: $0).environmentObject(root).environmentObject(TabBarViewViewModel())
        }
        .presentView(item: presentModal, style: .fullScreenWithBlender) {
            self.coordinator.go(to: $0).environmentObject(root).environmentObject(TabBarViewViewModel())
        }
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
        .onReceive(coordinator.presentModalSubject) { destination in
            destination.map {
                startRecordingPerformance(destination: $0)
            }
        }
    }

    private func startRecordingPerformance(destination: FinderCoordinator.Destination) {
        switch destination {
        case .none, .folder, .importPhoto, .importDocument, .camera, .createFolder, .nodeDetails, .rename, .move, .shareLink, .configShareMember, .createDocument, .createSheet, .openIn, .scanDocument, .servicePlans, .noSpaceLeftCloud, .noSpaceLeftLocally, .downloadToDevice:
            break
        case .file(let file):
            vm.startRecordingPerformance(node: file)
        case .protonFile(let file):
            vm.startRecordingPerformance(node: file)
        case .openInBrowser(let file):
            vm.startRecordingPerformance(node: file)
        case .openBookmark(let bookmark):
            vm.startRecordingPerformance(node: bookmark)
        }
    }

    @ViewBuilder var finderView: some View {
        ZStack {
            GridOrList(vm: vm, scrollToTopPublisher: vm.scrollToTopPublisher, contents1: {
                if !vm.transientChildren.isEmpty {
                    Section(header: uploadingBar, footer: Spacer(minLength: 30)) {
                        uploadDisclaimer
                        ForEach(vm.transientChildren.indices, id: \.self) { index in
                            nodeRow(isList: true, index: index, childrenList: vm.transientChildren)
                        }
                    }
                }
            }, contents2: {
                if !vm.permanentChildren.isEmpty {
                    Section(header: listHeader, footer: listFooter) {
                        ForEach(vm.permanentChildren.indices, id: \.self) { index in
                            nodeRow(isList: vm.layout == .list, index: index, childrenList: vm.permanentChildren)
                        }
                    }
                    .onAppear {
                        vm.reportListIsShown()
                    }
                }
            }, invitationViewsFactory: invitationViewsFactory)
            .dialogSheet(item: $menuItem, model: dialogSheetModel())

            if vm.needsNoConnectionBackground {
                NoConnectionView(isUpdating: $vm.isUpdating, refresh: vm.refreshOnAppear)
            }

            if let emptyConfig = vm.emptyBackgroundConfig {
                PlaceholderView(viewModel: emptyConfig)
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
            let lockedStateVM = LockedStateTopBannerViewModel(lockedStateBannerVisibility: vm.lockedStateBannerVisibility)
            LockedStateTopBannerView(viewModel: lockedStateVM)
        }
    }
    
    @ViewBuilder private var uploadDisclaimer: some View {
        if vm.isUploadDisclaimerVisible {
            NotificationBanner(
                message: Localization.upload_disclaimer,
                style: .inverted,
                padding: .vertical,
                closeBlock: vm.closeUploadDisclaimer
            )
        }
    }

    @ViewBuilder
    private var upgradeHintBanner: some View {
        let level = vm.upgradeRequirementLevel
        if let handling = vm.upgradeRequirementHandling {
            UpgradeRequirementBannerView(level: level, handling: handling)
        }
    }

    @ViewBuilder
    private func nodeRow(isList: Bool, index: Int, childrenList: [NodeWrapper]) -> some View {
        // There are crash reports with invalid index, that's why we try to access it safely.
        // Not sure what's the root cause, possibly `permanentChildren` gets changed by another thread.
        childrenList[safe: index].map {
            nodeRow($0, isList: isList, index: index)
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
        UploadingSectionHeader(title: Localization.general_uploading)
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
        case let .removeMe(vm: nodeVM):
            return nodeVM.makeRemoveMeAlert(
                environment: .init(
                    menuItem: $menuItem,
                    presentationMode: nil,
                    cancelSelection: (vm as? (any HasMultipleSelection))?.cancelSelection
                )
            )

        case let .removeBookmark(vm: nodeVM):
            return nodeVM.makeRemoveBookmarkAlert(
                environment: .init(
                    menuItem: $menuItem,
                    presentationMode: nil,
                    cancelSelection: (vm as? (any HasMultipleSelection))?.cancelSelection
                )
            )
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
        let editSectionEnvironment = EditSectionEnvironment(
            menuItem: $menuItem,
            modal: presentModal,
            sheet: $presentedSheet,
            acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage,
            featureFlagsController: coordinator.featureFlagsController
        )
        let nodes = selectionViewModel.selectedNodes()
        if let node = nodes.map(\.node).first {
            let nodeRowViewModel = NodeRowActionMenuViewModel(node: node, model: vm)

            ContextMenuView(icon: IconProvider.threeDotsHorizontal, color: ColorProvider.IconNorm, viewModifier: EmptyModifier()) {
                ForEach(nodeRowViewModel.editSections(environment: editSectionEnvironment)) { group in
                    ForEach(group.items) { item in
                        ContextMenuItemActionView(item: item)
                            .accessibility(identifier: "ContextMenuItemActionView.\(item.identifier)")
                    }
                    Divider()
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
