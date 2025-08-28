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

struct PhotosGalleryPlaceholderView<ViewModel: PhotosGalleryPlaceholderViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        // TODO: `Albums` related: we should differentiate between:
        // - empty when backup is running & the tag is `All`
        // - empty when backup is complete & tag is whatever
        // For now using generic empty photos.
        PlaceholderView(viewModel: configuration)
//        ZStack {
//            VStack(spacing: 20) {
//                ProgressView()
//                    .progressViewStyle(
//                        CircularProgressViewStyle(tint: .BrandNorm)
//                    )
//                Text(viewModel.title)
//                    .font(.body)
//                    .foregroundColor(ColorProvider.TextWeak)
//            }
//        }
//        .frame(maxHeight: .infinity)
//        .onAppear(perform: viewModel.didAppear)
//        .onDisappear(perform: viewModel.didDisappear)
    }

    private var configuration: PlaceholderViewConfiguration {
        .init(
            image: tagImage(),
            imageColor: imageColor(),
            title: viewModel.tagTitle,
            message: viewModel.tagMessage
        )
    }

    private func tagImage() -> PlaceholderViewConfiguration.Illustration {
        if let tag = viewModel.tag {
            let uiTag = PhotoUITag.existing(tag)
            return .image(uiTag.icon, 50, viewModel.tagIdentifier)
        } else {
            return .type(.emptyPhotos)
        }
    }

    private func imageColor() -> Color {
        if case .favorites = viewModel.tag {
            return ColorProvider.NotificationError
        } else {
            return ColorProvider.IconWeak
        }
    }
}
