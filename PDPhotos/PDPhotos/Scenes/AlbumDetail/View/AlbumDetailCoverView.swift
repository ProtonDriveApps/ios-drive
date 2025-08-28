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

import Foundation
import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents

struct AlbumDetailCoverView: View {
    @ObservedObject private var viewModel: AlbumDetailCoverViewModel
    @State private var coverImage: UIImage?
    private var scrollViewOffset: CGFloat

    init(scrollViewOffset: CGFloat, viewModel: AlbumDetailCoverViewModel) {
        self.scrollViewOffset = scrollViewOffset
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            cover()
            Spacer()
        }
        .onReceive(viewModel.coverIsChangedPublisher) { _ in
            self.coverImage = nil
        }
    }

    @ViewBuilder
    private func cover() -> some View {
        let height = AlbumDetailConstants.coverHeight + max(0, scrollViewOffset)
        GeometryReader { geometry in
            if viewModel.hasCover {
                coverPhoto(geometry: geometry, height: height)
            } else {
                placeholder(geometry: geometry, height: height)
            }
        }
    }

    @ViewBuilder
    private func coverPhoto(geometry: GeometryProxy, height: CGFloat) -> some View {
        if viewModel.coverData != nil {
            let cover = Image(uiImage: getCoverImage())

            cover
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: height)
                .overlay {
                    ColorProvider.BlenderNorm.opacity(opacity())
                }
                .clipped()
                .accessibilityIdentifier("AlbumDetailView.cover.photo")
        } else {
            ZStack {
                placeholder(geometry: geometry, height: height)
                ProtonSpinner(size: .custom(24), style: .inverted)
                    .accessibilityIdentifier("AlbumDetailView.cover.spinner")
            }
        }
    }

    private func getCoverImage() -> UIImage {
        if let coverImage {
            return coverImage
        } else if let data = viewModel.coverData {
            let image = UIImage(data: data) ?? UIImage()
            DispatchQueue.main.async {
                self.coverImage = image
            }
            return image
        } else {
            return UIImage()
        }
    }

    private func placeholder(geometry: GeometryProxy, height: CGFloat) -> some View {
        Rectangle()
            .fill(InternalColor.coverPlaceholderColor)
            .frame(width: geometry.size.width, height: height)
            .accessibilityIdentifier("AlbumDetailView.cover.placeholder")
    }

    private func opacity() -> CGFloat {
        let m = -0.00404  // slope
        let b = 0.4       // y-intercept
        let opacity = m * scrollViewOffset + b
        return max(min(opacity, 0.8), 0.4)
    }
}
