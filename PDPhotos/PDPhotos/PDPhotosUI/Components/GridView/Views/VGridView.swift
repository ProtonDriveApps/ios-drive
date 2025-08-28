// Copyright (c) 2024 Proton AG
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

public struct VGridView<VM: GridViewModelProtocol, ItemView: View>: View {
    @ObservedObject private var viewModel: VM
    @State private var elementWidth: CGFloat = UIScreen.main.bounds.width
    @Binding private var isRefreshing: Bool
    private var pullToRefresh: (() -> Void)?
    private let configuration: GridConfiguration
    private let shouldHasRefreshView: Bool
    private let shouldEmbedScrollView: Bool
    private let itemViewBuilder: (any GridViewItem, Int) -> ItemView
    private let coordinateSpace = "pullToRefreshSpace"

    init(
        viewModel: VM,
        configuration: GridConfiguration,
        shouldEmbedScrollView: Bool = true,
        isRefreshing: Binding<Bool>? = nil,
        pullToRefresh: (() -> Void)? = nil,
        itemViewBuilder: @escaping (any GridViewItem, Int) -> ItemView
    ) {
        self.viewModel = viewModel
        self.configuration = configuration
        self.itemViewBuilder = itemViewBuilder
        self.shouldEmbedScrollView = shouldEmbedScrollView
        self._isRefreshing = isRefreshing ?? .init(get: { false }, set: { _ in })
        self.shouldHasRefreshView = isRefreshing == nil ? false : true
        self.pullToRefresh = pullToRefresh
    }

    public var body: some View {
        container {
            content()
        }
        .background(.clear)
        .clipped()
    }

    @ViewBuilder
    private func container<Content: View>(content: () -> Content) -> some View {
        if shouldEmbedScrollView {
            ScrollView(content: content)
                .coordinateSpace(name: coordinateSpace)
        } else {
            VStack(spacing: 0, content: content)
        }
    }

    @ViewBuilder
    private func refreshView() -> some View {
        if shouldHasRefreshView {
            PullToRefreshView(
                isRefreshing: .constant(isRefreshing),
                subtitle: nil,
                coordinateSpaceName: coordinateSpace
            ) {
                pullToRefresh?()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func content() -> some View {
        refreshView()
        LazyVGrid(
            columns: columns(viewWidth: elementWidth),
            spacing: configuration.vSpacing,
            pinnedViews: [.sectionHeaders]
        ) {
            ForEach(viewModel.sections, id: \.id) { section in
                view(from: section)
            }
        }
        .padding(.top, 20)
        .modifier(GetWidthModifier(width: $elementWidth))
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .onAppear {
                viewModel.didShowLastItem()
            }
    }

    private func view(from section: GridViewSection) -> some View {
        Section(content: {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { item in
                itemViewBuilder(item.element, item.offset)
                    .aspectRatio(configuration.aspectRatio, contentMode: .fill)
            }
        }, header: {
            if let title = section.title {
                Text(title)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(ColorProvider.TextWeak)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: section.isFirst ? 14 : 24, leading: 16, bottom: 8, trailing: 16))
            }
        })
        .background(ColorProvider.BackgroundNorm)
    }
}

extension VGridView {
    private func columns(viewWidth: CGFloat) -> [GridItem] {
        let rowWidth = configuration.preferableItemWidth * (configuration.minimumNumberOfColumns) +
        configuration.hSpacing * (configuration.minimumNumberOfColumns - 1)
        if viewWidth >= rowWidth {
            return [GridItem(.adaptive(minimum: configuration.preferableItemWidth, maximum: .infinity), spacing: configuration.hSpacing)]
        } else {
            return Array(repeating: .init(.flexible(), spacing: configuration.hSpacing), count: 3)
        }
    }
}
