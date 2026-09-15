// Copyright (c) 2026 Proton AG
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

import PDCoreIOS
import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct FFinderView: View {
    @ObservedObject var viewModel: FFinderViewModel
    @State private var activeListHeaderShadow = false
    @State private var uploadingListHeaderShadow = false
    private let coordinateSpace = "pullToRefresh"

    init(viewModel: FFinderViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            topBanners()

            let allEmpty = viewModel.activeCellVMs.isEmpty && viewModel.uploadingCellVMs.isEmpty
            let isLoading = viewModel.isFetching || viewModel.isLoading
            if !allEmpty {
                childrenList
                Spacer()
                multipleSelectionActionBar()
                modalActionBar()
                    .fixedSize(horizontal: false, vertical: true)
            } else if !isLoading && allEmpty {
                if viewModel.isConnectionReachable {
                    PlaceholderView(viewModel: .folder)
                } else {
                    NoConnectionView(isUpdating: .constant(false), refresh: {
                        Task {
                            await viewModel.fetchAllChildren()
                        }
                    })
                }
                modalActionBar()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .flatNavigationBar(
            viewModel.scene.navigationTitle,
            leading: leadingBarButtons(viewModel.scene.leadingNavBarItems),
            trailingItems: viewModel.scene.trailingNavBarItems,
            trailingItem: navigationBarButton
        )
        .background(ColorProvider.BackgroundNorm)
        .task { await viewModel.onAppear() }
        .navigationBarBackButtonHidden(viewModel.isSelecting)
        .onAppear {
            viewModel.isVisible = true
            if viewModel.shouldShowVolumeLockBanner {
                viewModel.dependencies.coordinator.volumeLockController.resetBannerVisibilityForMyFilesAppear()
            }
        }
        .onDisappear {
            viewModel.isVisible = false
            viewModel.onDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard viewModel.isVisible else { return }
            Task { await viewModel.onAppear() }
        }
    }

    @ViewBuilder
    private func topBanners() -> some View {
        if viewModel.lockedStateBannerVisibility != .hidden {
            LockedStateTopBannerView(
                viewModel: LockedStateTopBannerViewModel(
                    lockedStateBannerVisibility: viewModel.lockedStateBannerVisibility
                )
            )
        }

        if viewModel.shouldShowVolumeLockBanner {
            VolumeLockBannerView(
                controller: viewModel.dependencies.coordinator.volumeLockController,
                tower: viewModel.dependencies.coordinator.tower,
                authenticator: viewModel.dependencies.coordinator.authenticator
            )
        }

        if let handling = viewModel.upgradeRequirementHandling {
            UpgradeRequirementBannerView(
                level: viewModel.upgradeRequirementLevel,
                handling: handling
            )
        }
    }
}

// MARK: - Navigation
extension FFinderView {
    @ViewBuilder
    private func leadingBarButtons(_ items: [NavigationBarButton]) -> some View {
        if !items.isEmpty {
            ForEach(items, content: navigationBarButton)
        }
    }

    @ViewBuilder
    private func navigationBarButton(_ item: NavigationBarButton) -> some View {
        switch item {
        case .virtualBack:
            BackButton { NotificationCenter.default.post(.virtualBack) }.any()

        case .menu:
            MenuButton { NotificationCenter.default.post(.toggleSideMenu) }.any()

        case .upload:
            let groups = viewModel.dependencies.uploadSectionFactory.make()

            ContextMenuView(icon: IconProvider.plus, viewModifier: ContextMenuNavigationModifier()) {
                ForEach(groups) { group in
                    ForEach(group.items) { item in
                        ContextMenuItemActionView(item: item)
                    }
                    Divider()
                }
            }
            .accessibility(identifier: "RoundButtonView.Button.Plus_Button")
            .opacity(viewModel.folder.permissions == .view ? 0 : 1)
            .disabled(viewModel.folder.permissions == .view)

        case .action:
            // TODO: finder-refactor, implement this for trash view
//            let environment = EditSectionEnvironment(
//                menuItem: $menuItem,
//                modal: presentModal,
//                sheet: $presentedSheet,
//                acknowledgedNotEnoughStorage: acknowledgedNotEnoughStorage,
//                featureFlagsController: coordinator.featureFlagsController
//            )
//            ContextMenuView(icon: IconProvider.threeDotsHorizontal, viewModifier: ContextMenuNavigationModifier()) {
//                ForEach(uploadSectionMenuViewItems(environment: environment)) { group in
//                    Divider()
//                    ForEach(group.items) { item in
//                        ContextMenuItemActionView(item: item)
//                    }
//                }
//                ForEach(editSectionMenuItems(environment: environment)) { group in
//                    Divider()
//                    ForEach(group.items) { item in
//                        ContextMenuItemActionView(item: item)
//                    }
//                }
//            }
//            .accessibility(identifier: "ContextMenuView.Button.Three_Dots_Horizontal")
            MenuButton { NotificationCenter.default.post(.toggleSideMenu) }.any()

        case let .apply(title, disabledInCurrentContext):
            let isUpdating = viewModel.isFetching || viewModel.isLoading
            let formattedTitle = title.components(separatedBy: " ").map { $0.capitalized }.joined()
            TextNavigationBarButton(title: title){ [weak viewModel] in
                viewModel?.applyAction()
            }
            .accessibility(identifier: "FinderView.NavigationBarButton.TextButton.RightActionButton.\(formattedTitle)")
            .disabled(isUpdating || disabledInCurrentContext)
            .fixedSize()

        case .toggleSelectAll(let title):
            let formattedTitle = title.components(separatedBy: " ").map { $0.capitalized }.joined()
            TextNavigationBarButton(title: title) { [weak viewModel] in
                viewModel?.toggleSelectAll()
            }
            .accessibility(identifier: "FinderView.NavigationBarButton.TextButton.RightActionButton.\(formattedTitle)")
            .fixedSize()
            .padding(.horizontal, 8)

        case .cancel:
            TextNavigationBarButton(title: "Cancel", weight: .bold) { [weak viewModel] in
                viewModel?.disableSelectionMode()
            }
            .fixedSize()
            .padding(.horizontal, 8)
        case .subscribe:
            SubscriptionBarItem { [weak viewModel] in
                viewModel?.onTapSubscription()
            }
        default:
            AssertionView("Unsupported NavigationBarButton requested")
        }
    }
}

// MARK: - Header
extension FFinderView {
    @ViewBuilder
    private func listHeader() -> some View {
        let supportsLayoutSwitch = viewModel.dependencies.scene.supportsLayoutSwitch
        let supportsSortingSwitch = viewModel.dependencies.scene.supportsSortingSwitch
        if supportsLayoutSwitch || supportsSortingSwitch {
            let switchSorting = supportsSortingSwitch ? { newSorting in viewModel.switchSorting(newSorting) } : nil
            let changeLayout = supportsLayoutSwitch ? viewModel.changeLayout : nil
            FinderConfigurationView(
                sortingText: viewModel.sortPreference.title,
                switchSorting: switchSorting,
                sorting: viewModel.sortPreference,
                layout: viewModel.layout,
                changeLayout: changeLayout
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .modifier(HeaderShadowModifier(visible: $activeListHeaderShadow))
        }
    }
    
    private var listFooter: some View {
        NodesListFooter(text: "")
            .onAppear(perform: viewModel.didScrollToBottom)
    }
    
    private var uploadingHeader: some View {
        UploadingSectionHeader(title: Localization.general_uploading)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .padding(.vertical, 8)
            .modifier(HeaderShadowModifier(visible: $uploadingListHeaderShadow))
    }
    
    @ViewBuilder
    private func uploadDisclaimer() -> some View {
        if viewModel.isUploadDisclaimerVisible {
            NotificationBanner(
                message: Localization.upload_disclaimer,
                style: .inverted,
                padding: .vertical,
                closeBlock: viewModel.closeUploadDisclaimer
            )
        }
    }
}

// MARK: - Children list
extension FFinderView {
    private var childrenList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                EmptyView()
                    .id("top")
                PullToRefreshView(
                    isRefreshing: .constant(viewModel.isFetching),
                    subtitle: viewModel.refreshControlSubtitle.string,
                    coordinateSpaceName: coordinateSpace
                ) {
                    Task.detached {
                        await viewModel.fetchAllChildren()
                    }
                }
                uploadingList()
                activeList()
            }
            .coordinateSpace(name: coordinateSpace)
            .modifier(HeaderScrollObserver<GridOrListSection1OffsetPreferenceKey>(visible: $uploadingListHeaderShadow))
            .modifier(HeaderScrollObserver<GridOrListSection2OffsetPreferenceKey>(visible: $activeListHeaderShadow))
            .onReceive(viewModel.scrollToTopPublisher) { _ in
                withAnimation {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }
    
    @ViewBuilder
    private func uploadingList() -> some View {
        if !viewModel.uploadingCellVMs.isEmpty {
            let layout = Layout.list
            LazyVGrid(
                columns: layout.finderLayout,
                alignment: .center,
                spacing: layout.spacing,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    uploadDisclaimer()
                    ForEach(Array(viewModel.uploadingCellVMs.enumerated()), id: \.element.node.id) { (index, cellVM) in
                        FFinderCell(viewModel: cellVM, index: index, layout: layout)
                    }
                } header: {
                    uploadingHeader
                } footer: {
                    Spacer(minLength: 30)
                }
            }
            .modifier(HeaderScrollSignal<GridOrListSection1OffsetPreferenceKey>(coordinateSpace: coordinateSpace))
        }
    }
    
    @ViewBuilder
    private func activeList() -> some View {
        if !viewModel.activeCellVMs.isEmpty {
            let layout = viewModel.layout
            LazyVGrid(
                columns: layout.finderLayout,
                alignment: .center,
                spacing: layout.spacing,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    ForEach(Array(viewModel.activeCellVMs.enumerated()), id: \.element.node.id) { (index, cellVM) in
                        FFinderCell(
                            viewModel: cellVM,
                            index: index,
                            layout: layout,
                            onTap: {
                                viewModel.onTapCell(nodeID: cellVM.node.id)
                            },
                            onLongPress: {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                viewModel.onLongPressCell()
                            }
                        )
                    }
                } header: {
                    listHeader()
                } footer: {
                    listFooter
                }
            }
            .modifier(HeaderScrollSignal<GridOrListSection2OffsetPreferenceKey>(coordinateSpace: coordinateSpace))
        }
    }
}

// MARK: - Bottom action bar
extension FFinderView {
    @ViewBuilder
    private func multipleSelectionActionBar() -> some View {
        let selected = viewModel.activeCellVMs.filter({ $0.isSelected }).map(\.node)
        let actionItems = viewModel.scene.bottomActionItems(selected: selected)
        Group {
            if let selectionVM = viewModel.dependencies.multipleSelectionModel, !selectionVM.selected.isEmpty {
                ActionBar(
                    onSelection: { action in
                        viewModel.handleMultipleSelectionAction(action)
                    },
                    items: actionItems,
                    isContainedInVStack: true, // Prevents content hugging
                    content: {
                        actionBarMoreButton()
                    }
                )
                .opacity(selectionVM.selected.isEmpty ? 0 : 1)
                .transaction { $0.animation = .easeInOut }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func actionBarMoreButton() -> some View {
        let selectionVM = viewModel.dependencies.multipleSelectionModel
        if selectionVM?.selected.count == 1,
           let node = viewModel.activeCellVMs.first(where: { $0.isSelected })?.node {

            let actionVM = viewModel.bottomActionMoreButtonVM(node: node)
            ContextMenuView(
                icon: IconProvider.threeDotsHorizontal,
                color: ColorProvider.IconNorm,
                viewModifier: EmptyModifier()
            ) {
                ForEach(actionVM.editActionGroups()) { group in
                    ForEach(group.items) { item in
                        ContextMenuItemActionView(item: item)
                            .accessibility(identifier: "ContextMenuItemActionView.\(item.identifier)")
                    }
                    Divider()
                }
                if node.isFile, let moreGroup = actionVM.moreActionGroup() {
                    Divider()
                    ForEach(moreGroup.items) { item in
                        ContextMenuItemActionView(item: item)
                            .accessibility(identifier: item.identifier)
                    }
                }
            }
            .frame(width: 20, height: 20)
            .accessibility(identifier: "ActionBar.Button.MoreSingle")
        }
    }

    @ViewBuilder
    private func modalActionBar() -> some View {
        if viewModel.dependencies.scene.hasModalActionBar {
            ActionBar(
                onSelection: { viewModel.handleOverlayAction($0) },
                leadingItems: viewModel.dependencies.scene.modalLeadingActionItems,
                trailingItems: viewModel.dependencies.scene.modalTrailingActionItems
            )
        }
    }
}
