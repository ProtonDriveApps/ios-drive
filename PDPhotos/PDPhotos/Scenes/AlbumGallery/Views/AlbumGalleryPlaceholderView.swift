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
import PDUIComponents
import ProtonCoreUIFoundations

struct AlbumGalleryPlaceholderView: View {
    private let viewModel: AlbumGalleryPlaceholderViewModel
    private let safeArea: EdgeInsets
    private var createAlbum: () -> Void

    init(currentTag: AlbumUITag, safeArea: EdgeInsets, createAlbum: @escaping () -> Void) {
        self.viewModel = .init(currentTag: currentTag)
        self.safeArea = safeArea
        self.createAlbum = createAlbum
    }

    var body: some View {
        PlaceholderView(
            viewModel: config,
            footer: {
                Group {
                    if viewModel.shouldShowCreateButton {
                        button
                    }
                    Spacer()
                }
            }
        )
        .padding(.top, padding)
    }

    private var button: some View {
        Button {
            createAlbum()
        } label: {
            Text(viewModel.createAlbumActionTitle)
                .font(.body)
                .foregroundStyle(.white)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(ColorProvider.InteractionNorm)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
        }
    }

    private var config: PlaceholderViewConfiguration {
        return .init(
            image: .image(InternalIcon.albumIllustration, 152, "empty-albums"),
            title: viewModel.placeholderTitle,
            message: viewModel.placeholderMessage
        )
    }

    private var padding: CGFloat {
        // Adjust the padding to center the placeholder vertically on the device
        return -1 * (safeArea.top + safeArea.bottom) / 2
    }
}
