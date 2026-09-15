// Copyright (c) 2026 Proton AG
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

/// SwiftUI bridge for the UICollectionView-backed photos grid.
///
/// Generic over the cell content view so call sites stay type-safe; the item
/// builder is erased to `AnyView` for the concrete view controller.
struct PhotosCollectionView<ItemView: View>: UIViewControllerRepresentable {
    let viewModel: PhotosGridViewModel
    let item: (PhotoGridViewItem, String) -> ItemView
    let zoomController: PhotosGridZoomController
    var bottomContentInset: CGFloat = 0
    var showsScrollIndicator: Bool = true
    var onScrolledChanged: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> PhotosCollectionViewController {
        PhotosCollectionViewController(
            viewModel: viewModel,
            item: { AnyView(item($0, $1)) },
            zoomController: zoomController,
            onScrolledChanged: onScrolledChanged
        )
    }

    func updateUIViewController(_ controller: PhotosCollectionViewController, context: Context) {
        controller.setBottomInset(bottomContentInset)
        controller.setShowsScrollIndicator(showsScrollIndicator)
    }
}
