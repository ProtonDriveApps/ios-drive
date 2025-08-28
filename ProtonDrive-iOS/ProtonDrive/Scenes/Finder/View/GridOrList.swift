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

import Combine
import SwiftUI
import PDCore
import PDCoreIOS
import PDUIComponents

struct GridOrList<ViewModel: ObservableFinderViewModel, Content1: View, Content2: View>: View {
    @ObservedObject var vm: ViewModel
    
    let contents1: Content1
    let contents2: Content2
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>
    @State private var isVisible: Bool = false
    private let invitationViewsFactory: PendingInvitationsListViewFactory?

    private let coordinateSpace = "pullToRefresh"
    
    init(vm: ViewModel,
         scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?,
         @ViewBuilder contents1: () -> Content1,
         @ViewBuilder contents2: () -> Content2,
         invitationViewsFactory: PendingInvitationsListViewFactory? = nil
    ) {
        self.vm = vm
        self.scrollToTopPublisher = scrollToTopPublisher ?? PassthroughSubject<TabBarItem, Never>().eraseToAnyPublisher()
        self.contents1 = contents1()
        self.contents2 = contents2()
        self.invitationViewsFactory = invitationViewsFactory
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    EmptyView()
                        .id("top")
                    if let rvm = vm as? HasRefreshControl {
                        PullToRefreshView(isRefreshing: .constant(vm.isUpdating), subtitle: refreshSubtitle?.string, coordinateSpaceName: coordinateSpace) { rvm.refreshControlAction() }
                    }

                    if let ivm = vm as? SharedWithMeViewModel, let invitationViewsFactory = invitationViewsFactory {
                        NavigationLink(
                            destination: LazyDrilldown(invitationViewsFactory.makeListView())
                        ) {
                            PendingSharedItemsView(viewModel: ivm.pendingInvitationsViewModel)
                        }
                        .accessibilityIdentifier("PendingInvitationsLink")
                    }

                    LazyVGrid(columns: Layout.list.finderLayout, alignment: .center, spacing: Layout.list.spacing, pinnedViews: [.sectionHeaders]) {
                        contents1
                    }
                    .modifier(HeaderScrollSignal<GridOrListSection1OffsetPreferenceKey>(coordinateSpace: coordinateSpace))

                    LazyVGrid(columns: vm.layout.finderLayout, alignment: .center, spacing: vm.layout.spacing, pinnedViews: [.sectionHeaders]) {
                        contents2
                    }
                    .padding(.bottom, ActionBarSize.height)
                    .modifier(HeaderScrollSignal<GridOrListSection2OffsetPreferenceKey>(coordinateSpace: coordinateSpace))
                }
            }
            .coordinateSpace(name: coordinateSpace)
            .onReceive(scrollToTopPublisher) { _ in
                // Known issue
                // If you tap a non-open tab item twice quickly, the onDisappear method of the current view will not be called in time.
                // As a result, the current view will unexpectedly scroll to the top.
                if isVisible {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }

    private var refreshSubtitle: NSAttributedString? {
        (self.vm as? HasRefreshControl)?.refreshControlSubtitle
    }
}
