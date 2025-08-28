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
import PDCoreIOS
import PDUIComponents
import ProtonCoreUIFoundations

struct GroupToAlbumActionSheetCell: View {
    @ObservedObject private var viewModel: AlbumGridItemViewModel

    init(viewModel: AlbumGridItemViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        HStack(spacing: 0) {
            albumCover()
            VStack(spacing: 4) {
                albumTitle
                viewModel.albumType.map(makeSubtitle)
            }
            .padding(.leading, 12)
            photoCount
                .padding(.leading, 16)
        }
        .task {
            await MainActor.run { viewModel.onAppear() }
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    @ViewBuilder
    private func cover() -> some View {
        if let image = viewModel.image {
            Image(uiImage: UIImage(data: image) ?? UIImage())
                .resizable()
                .accessibilityIdentifier("GroupToAlbumActionSheetCell.\(viewModel.title).cover.image")
        } else {
            InternalIcon.fileAlbumNoPadding
                .resizable()
                .accessibilityIdentifier("GroupToAlbumActionSheetCell.\(viewModel.title).cover.placeholder")
        }
    }

    @ViewBuilder
    private func albumCover() -> some View {
        cover()
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var albumTitle: some View {
        Text(viewModel.title)
            .modifier(ResizableTextModifier(font: .body, textColor: ColorProvider.TextNorm))
            .accessibilityIdentifier("GroupToAlbumActionSheetCell.\(viewModel.title)")
    }

    private func makeSubtitle(_ text: String) -> some View {
        Text(text)
            .modifier(ResizableTextModifier(font: .footnote, textColor: ColorProvider.TextHint))
            .accessibilityIdentifier("GroupToAlbumActionSheetCell.Subtitle.\(text)")
    }

    private var photoCount: some View {
        Text("\(viewModel.photoCount)")
            .modifier(ResizableTextModifier(font: .footnote, textColor: ColorProvider.TextHint, maxWidth: nil))
            .frame(width: 32, height: 32)
            .accessibilityIdentifier("GroupToAlbumActionSheetCell.\(viewModel.title).count.\(viewModel.photoCount)")
    }
}
