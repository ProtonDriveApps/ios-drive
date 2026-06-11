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
import ProtonCoreUIFoundations
import PDUIComponents

struct PhotosGridView<
    ViewModel: PhotosGridViewModelProtocol,
    ActionView: View,
    ItemView: View,
    BannersView: View,
    ScrollerView: View
>: View {
    @ObservedObject private var viewModel: ViewModel
    private let navigationFactory: PhotosRootNavigationButtonFactory
    private let actionView: ActionView
    private let bannersView: BannersView
    private let scrollerView: ScrollerView
    private let item: (PhotoGridViewItem, String) -> ItemView
    
    private let itemAspectRatio: CGFloat = 1 / 1.4
    private let minimumNumberOfColumns: CGFloat = 3
    private let preferableItemWidth: CGFloat = 128
    private let idealSectionHeaderHeight: CGFloat = 45
    private let spacing: CGFloat = 1.5
    @State var bottomPadding: CGFloat = 0
    @State var isScrolled = false
    private let coordinateSpace = "PhotosGridViewCoordinateSpace"
    @State private var contentBounds: CGRect = .zero

    init(
        viewModel: ViewModel,
        navigationFactory: PhotosRootNavigationButtonFactory,
        actionView: ActionView,
        bannersView: BannersView,
        scrollerView: ScrollerView,
        item: @escaping (PhotoGridViewItem, String) -> ItemView
    ) {
        self.viewModel = viewModel
        self.navigationFactory = navigationFactory
        self.actionView = actionView
        self.bannersView = bannersView
        self.scrollerView = scrollerView
        self.item = item
    }

    var body: some View {
        contentWithOptionalNavigation
            .overlay(alignment: .bottom) {
                if viewModel.configuration.isPickingPhotos {
                    floatingSelectionConfirmView
                } else {
                    VStack(spacing: 0) {
                        if !isScrolled && !viewModel.configuration.isPickingPhotos {
                            bannersView
                        }
                        actionView
                    }
                    .background(paddingView)
                }
            }
            .onAppear(perform: viewModel.onAppear)
            .errorToast(location: .bottom, errors: viewModel.error)
    }

    @ViewBuilder
    private var contentWithOptionalNavigation: some View {
        contentIncludingScroller
            .toolbar {
                if let navigation = viewModel.navigation {
                    toolbarContent(navigation: navigation)
                }
            }
    }

    private var contentIncludingScroller: some View {
        ZStack(alignment: .trailing) {
            content
            scrollerView
        }
    }

    private var content: some View {
        GeometryReader { geometry in
            OffsettableScrollView(
                showsIndicator: !viewModel.isUsingCustomScroller,
                onOffsetChanged: { offset in
                    updateScrollFlag(offset: offset)
                },
                onRefresh: { [viewModel] in
                    viewModel.refresh()
                },
                content: { proxy in
                    VStack(spacing: 0) {
                        LazyVGrid(
                            columns: columns(width: geometry.size.width),
                            alignment: .leading,
                            spacing: spacing,
                            pinnedViews: [.sectionHeaders]
                        ) {
                            ForEach(viewModel.sections, id: \.id) {
                                view(from: $0)
                            }
                        }
                        .onAppear {
                            viewModel.reportListIsShown()
                        }

                        bottomView
                            .padding(.top, 16)

                        Spacer(minLength: bottomPadding)
                    }
                    .onReceive(viewModel.scrollToItem) { item in
                        // Very important to not animate if possible
                        // With animation, swiftui would initialize all items (and their viewmodels) in between which
                        // leads to an unnecessary CPU spike.
                        withAnimation(nil) {
                            // Offset is needed because of section headers.
                            // Using anchor `.top` results in the item being scrolled below the header partially
                            let offset = (idealSectionHeaderHeight + 15) / geometry.size.height
                            let anchor = UnitPoint(x: 0, y: offset)
                            proxy.scrollTo(item, anchor: anchor)
                        }
                    }
                    .onPreferenceChange(ChildViewFramePreferenceKey.self) { childFrames in
                        var visibleChildFrames = [PhotoGridViewItem: CGRect]()
                        let topSectionFrame = CGRect(x: 0, y: 0, width: geometry.size.width, height: 150)
                        for (item, childFrame) in childFrames where topSectionFrame.intersects(childFrame) {
                            visibleChildFrames[item] = childFrame
                        }
                        let sortedItems = visibleChildFrames.keys.sorted(by: { $0.captureTime > $1.captureTime })
                        if let topChild = sortedItems.first {
                            viewModel.updateTopItem(topChild)
                        }
                    }
                }
            )
        }
        .coordinateSpace(name: coordinateSpace)
    }

    private func updateScrollFlag(offset: CGPoint) {
        viewModel.setUpdatedScrollOffset()

        let isScrolled = offset.y < 0
        guard self.isScrolled != isScrolled else {
            return
        }
        withAnimation {
            self.isScrolled = isScrolled
        }
    }

    private func columns(width: CGFloat) -> [GridItem] {
        let widthForExtraColumns = preferableItemWidth * (minimumNumberOfColumns + 1) + spacing * (minimumNumberOfColumns - 1)
        if width >= widthForExtraColumns {
            return [GridItem(.adaptive(minimum: preferableItemWidth, maximum: .infinity), spacing: spacing)]
        } else {
            return Array(repeating: .init(.flexible(), spacing: spacing), count: 3)
        }
    }

    private func view(from section: PhotosGridViewSection) -> some View {
        Section(content: {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { tuple in
                item(tuple.element, "\(section.title)_\(tuple.offset)")
                    .aspectRatio(itemAspectRatio, contentMode: .fit)
                    .overlay(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ChildViewFramePreferenceKey.self,
                                value: [tuple.element: geometry.frame(in: .global)]
                            )
                        }
                    )
            }
        }, header: {
            Text(section.title)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(ColorProvider.TextWeak)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 8, trailing: 16))
                .frame(idealHeight: idealSectionHeaderHeight)
        }, footer: {
            Spacer().frame(height: 10)
        })
        .background(ColorProvider.BackgroundNorm)
    }

    private var bottomView: some View {
        VStack(spacing: 0) {
            switch viewModel.paginationStatus {
            case .finished:
                EmptyView()
            case .loading:
                ProtonSpinner(size: .small)
                    .padding(.bottom)
            case .error:
                Text(viewModel.footerError)
                    .tint(ColorProvider.NotificationError)
                    .padding(.bottom)
            }

            endToEndEncrypted
        }
        .padding(.bottom, 16)
        .onAppear(perform: viewModel.didShowLastItem)
    }

    private var endToEndEncrypted: some View {
        HStack(alignment: .center, spacing: 6) {
            Spacer()
            IconProvider.lockCheckFilled
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(ColorProvider.IconWeak)
            Text(viewModel.footer)
                .font(.caption)
                .foregroundColor(ColorProvider.TextWeak)
            Spacer()
        }
        .padding(.bottom, 16)
        .onAppear(perform: viewModel.didShowLastItem)
    }

    private var floatingSelectionConfirmView: some View {
        FloatingConfirmSelectionButton(
            selectionNumber: .init(get: { viewModel.selectionNumber }, set: { _ in }),
            cancelAction: { viewModel.deselectAll() },
            addAction: { viewModel.selectionFinalized() }
        )
    }

    private var paddingView: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    bottomPadding = proxy.size.height
                }
                .onChange(of: proxy.size) { _ in
                    bottomPadding = proxy.size.height
                }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(navigation: PhotosRootNavigation) -> some ToolbarContent {
        if let navigationTitle = navigation.title {
            navigationFactory.makeToolbar(
                title: navigationTitle,
                leading: navigation.leading,
                trailing: navigation.trailing,
                block: viewModel.handle(navigation:)
            )
        }
    }
}

private struct ActionViewHeightKey: PreferenceKey {
    typealias Value = CGFloat

    static var defaultValue: Value = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private struct ChildViewFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PhotoGridViewItem: CGRect] = [:]

    static func reduce(value: inout [PhotoGridViewItem: CGRect], nextValue: () -> [PhotoGridViewItem: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
