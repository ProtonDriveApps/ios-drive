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

import ProtonCoreUIFoundations
import SwiftUI
import PDUIComponents

struct PhotosGalleryView<
    ViewModel: PhotosGalleryViewModelProtocol,
    GridView: View,
    PlaceholderView: View,
    TagsView: View,
    BannersView: View
>: View {
    @ObservedObject private var viewModel: ViewModel
    private let grid: (BannersView) -> GridView
    private let placeholder: (PhotoTag?) -> PlaceholderView
    private let tagsView: TagsView
    private let bannersView: BannersView
    private let coordinateSpace = "pullToRefreshSpace"

    init(
        viewModel: ViewModel,
        grid: @escaping (BannersView) -> GridView,
        placeholder: @escaping (PhotoTag?) -> PlaceholderView,
        tagsView: TagsView,
        bannersView: BannersView
    ) {
        self.viewModel = viewModel
        self.grid = grid
        self.placeholder = placeholder
        self.tagsView = tagsView
        self.bannersView = bannersView
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)
            if viewModel.shouldShowFilterView {
                tagsView
                    .zIndex(1) // Grid contains custom scroller that needs not to overlap tags view
            }
            content
        }
        .errorToast(location: .bottom, errors: viewModel.error)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .placeholder(let tag):
            viewInScrollView {
                placeholder(tag)
            }
            .overlay(alignment: .bottom) {
                bannersView.opacity(viewModel.configuration.isPickingPhotos ? 0 : 1)
            }
        case .grid:
            grid(bannersView)
        case .loading:
            viewInScrollView {
                VStack {
                    ProtonSpinner(size: .medium, isHugging: true)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottom) {
                bannersView.opacity(viewModel.configuration.isPickingPhotos ? 0 : 1)
            }
        case .empty:
            viewInScrollView {
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func viewInScrollView(with content: @escaping () -> some View) -> some View {
        VStackWithPullToRefresh(isRefreshing: .constant(viewModel.isRefreshing), onRefresh: {
            viewModel.refresh()
        }, content: {
            content()
        })
    }
}
