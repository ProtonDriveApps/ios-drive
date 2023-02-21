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
import PDUIComponents

struct GridOrList<ViewModel: ObservableFinderViewModel, Content1: View, Content2: View>: View {
    @ObservedObject var vm: ViewModel
    
    let contents1: Content1
    let contents2: Content2
    
    private let coordinateSpace = "pullToRefresh"
    
    init(vm: ViewModel,
         @ViewBuilder contents1: () -> Content1,
         @ViewBuilder contents2: () -> Content2)
    {
        self.vm = vm
        self.contents1 = contents1()
        self.contents2 = contents2()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let rvm = vm as? HasRefreshControl {
                    PullToRefresh(needRefresh: .constant(vm.isUpdating), subtitle: refreshSubtitle?.string, coordinateSpaceName: coordinateSpace) { rvm.refreshControlAction() }
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
    }

    private var refreshSubtitle: NSAttributedString? {
        (self.vm as? HasRefreshControl)?.refreshControlSubtitle
    }
}
