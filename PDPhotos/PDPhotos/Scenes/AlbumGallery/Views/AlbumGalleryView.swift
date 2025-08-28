// Copyright (c) 2025 Proton AG
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

struct AlbumGalleryView<
    ViewModel: AlbumGalleryViewModelProtocol,
    InvitationsView: View
>: View {
    @ObservedObject var viewModel: ViewModel
    private let invitationsView: InvitationsView
    @State private var safeArea: EdgeInsets = .init()

    init(viewModel: ViewModel, invitationsView: InvitationsView) {
        self.viewModel = viewModel
        self.invitationsView = invitationsView
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)
            if viewModel.shouldShowFilter {
                tagRows
            }
            if !viewModel.configuration.isPickingPhotos {
                invitationsView
            }
            content
        }
        .background(ColorProvider.BackgroundNorm)
        .overlay(alignment: .bottom, content: {
            if viewModel.configuration.isPickingPhotos {
                floatingSelectionConfirmView
            }
        })
        .onAppear {
            viewModel.onAppear()
        }
        .modifier(GetSafeAreaInsetsModifier(safeAreaInsets: $safeArea))
    }

    private var content: some View {
        ZStack {
            placeholderView
            VStack {
                galleryView
                    .frame(height: viewModel.shouldShowPlaceholder ? 250 : nil)
                Spacer()
            }
        }
    }

    private var galleryView: some View {
        VGridView(
            viewModel: viewModel.gridViewModel,
            configuration: .album(),
            isRefreshing: .constant(viewModel.isRefreshControlVisible),
            pullToRefresh: {
                viewModel.refresh()
            },
            itemViewBuilder: { item, _ in
                let vm = viewModel.makeAlbumGridItemViewModel(id: item.id)
                return AlbumGridItemView(item: vm, maximumWidth: 160)
                    .onTapGesture {
                        viewModel.openAlbum(id: item.id)
                    } 
            }
        )
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var placeholderView: some View {
        if viewModel.shouldShowPlaceholder {
            AlbumGalleryPlaceholderView(currentTag: viewModel.currentTag, safeArea: safeArea) {
                self.viewModel.openAlbumCreation()
            }
        } else if viewModel.shouldShowSpinner {
            ProtonSpinner(size: .medium)
        } else {
            EmptyView()
        }
    }

    private var tagRows: some View {
        // TODO: `Albums` related: needs persisting of selected tag (in memory in viewModel)
        TagRowView(tags: AlbumUITag.allCases(), selectedTag: viewModel.currentTag, selectedTagDidChanged: { tags in
            guard let tag = (tags as? [AlbumUITag])?.first else { return }
            viewModel.list(albumType: tag)
        })
    }

    private var floatingSelectionConfirmView: some View {
        FloatingConfirmSelectionButton(
            selectionNumber: .init(get: { viewModel.selectionNumber }, set: { _ in }),
            cancelAction: { viewModel.deselectAll() },
            addAction: { viewModel.selectionFinalized() }
        )
    }
}
