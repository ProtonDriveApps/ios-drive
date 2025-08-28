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

struct AlbumGridItemView: View {
    @ObservedObject private var item: AlbumGridItemViewModel
    private let maximumWidth: CGFloat

    init(item: AlbumGridItemViewModel, maximumWidth: CGFloat) {
        self.item = item
        self.maximumWidth = maximumWidth
    }

    var body: some View {
        VStack(spacing: 4) {
            albumCover()
            Spacer().frame(height: 4)
            albumName
            albumDesc
        }
        .contentShape(Rectangle())
        .onAppear {
            item.onAppear()
        }
        .onDisappear {
            item.onDisappear()
        }
    }

    @ViewBuilder
    private func albumCover() -> some View {
        coverView()
            .frame(width: 160, height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 3))
                    .fill(InternalColor.albumGridBorder)
            }
            .rotationEffect(.degrees(degrees))
            .shadow(color: .black.opacity(0.16), radius: 8)
    }

    private var albumName: some View {
        Text(item.title)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(ColorProvider.TextNorm)
            .lineLimit(1)
            .frame(maxWidth: maximumWidth, alignment: .leading)
            .truncationMode(.tail)
            .accessibilityIdentifier("AlbumGridItemView.AlbumName.\(item.title)")
    }

    private var albumDesc: some View {
        Text(item.fullDescription)
            .font(.footnote)
            .foregroundStyle(ColorProvider.TextWeak)
            .frame(maxWidth: maximumWidth, alignment: .leading)
            .accessibilityIdentifier("AlbumGridItemView.AlbumDesc.\(item.title).\(item.fullDescription)")
    }

    @ViewBuilder
    private func coverView() -> some View {
        if let data = item.image,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityIdentifier("AlbumGridItemView.cover.\(item.title).image")
        } else {
            ZStack {
                ColorProvider.InteractionWeak
                InternalIcon.albumIllustration
                    .resizable()
                    .frame(width: 52, height: 40)
            }
            .accessibilityIdentifier("AlbumGridItemView.cover.\(item.title).placeholder")
        }
    }

    @ViewBuilder
    private func coverImageView(cover: Image) -> some View {
        cover
            .frame(width: 160, height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 3))
                    .fill(InternalColor.albumGridBorder)
            }
            .rotationEffect(.degrees(degrees))
            .shadow(color: .black.opacity(0.16), radius: 8)
    }

    private var coverPlaceholderView: some View {
        ZStack {
            ColorProvider.BackgroundDeep
            IconProvider.image
                .foregroundStyle(ColorProvider.IconHint)
        }
        .frame(width: 160, height: 160)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 3))
                .fill(InternalColor.albumGridBorder)
        }
        .rotationEffect(.degrees(degrees))
        .shadow(color: .black.opacity(0.16), radius: 8)
    }

    private var degrees: Double {
        let degrees: [Double] = [-2, -1, 0, 1, 2]
        let idx = abs(item.id.id.hashValue) % 5
        return degrees[idx]
    }
}
