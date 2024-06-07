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

struct PhotosGalleryView<
    ViewModel: PhotosGalleryViewModelProtocol,
    GridView: View,
    PlaceholderView: View,
    StateView: View,
    LockingView: View,
    StorageView: View
>: View {
    @ObservedObject private var viewModel: ViewModel
    private let grid: () -> GridView
    private let placeholder: () -> PlaceholderView
    private let stateView: StateView
    private let lockingBannerView: LockingView
    private let storageView: StorageView

    init(viewModel: ViewModel, grid: @escaping () -> GridView, placeholder: @escaping () -> PlaceholderView, stateView: StateView, lockingBannerView: LockingView, storageView: StorageView) {
        self.viewModel = viewModel
        self.grid = grid
        self.placeholder = placeholder
        self.stateView = stateView
        self.lockingBannerView = lockingBannerView
        self.storageView = storageView
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)
            stateView
            lockingBannerView
            storageView
            Spacer(minLength: 0)
            content
        }
        .errorToast(location: .bottom, errors: viewModel.error)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .grid:
            grid()
        case .loading:
            placeholder()
        case .empty:
            EmptyView()
        }
    }
}
