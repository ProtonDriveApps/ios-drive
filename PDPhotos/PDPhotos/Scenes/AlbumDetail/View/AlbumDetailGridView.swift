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
import PDLocalization
import PDUIComponents

struct AlbumDetailGridView: View {
    @ObservedObject private var viewModel: AlbumDetailGridViewModel

    init(viewModel: AlbumDetailGridViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        if let photoViewModel = viewModel.photoViewModel {
            if viewModel.gridViewItems.isEmpty {
                emptyStateView
                    .onAppear(perform: viewModel.onEmptyStateAppear)
            } else {
                photoGallery(photoViewModel: photoViewModel)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func photoGallery(photoViewModel: PhotoListingGridViewModel) -> some View {
        VGridView(
            viewModel: photoViewModel,
            configuration: .photosInAlbum(),
            shouldEmbedScrollView: false
        ) { item, idx in
            PhotoItemWrapperView {
                let viewModel = viewModel.makeItemViewModel(from: item as! PhotoGridViewItem)
                return PhotoItemView(viewModel: viewModel, accessibilityIndex: "\(idx)")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 0) {
            InternalIcon.albumIllustration
                .resizable()
                .frame(width: 195, height: 152)
                .padding(.top, 45)

            Text(Localization.empty_photos_title)
                .modifier(ResizableTextModifier(alignment: .center, font: .title2, fontWeight: .bold, textColor: ColorProvider.TextNorm))
                .padding(.top, 16)

            Text(Localization.album_empty_photo_desc)
                .modifier(ResizableTextModifier(alignment: .center, font: .body, textColor: ColorProvider.TextNorm))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
        .padding(.horizontal, 30)
    }

}
