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

struct PhotosPreviewActionView<ViewModel: PhotosPreviewActionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @State private var idealHeight: CGFloat = 0

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ActionBar(
            onSelection: { model in
                PhotosActionBarMapping.photosAction(for: model).map(viewModel.handle(action:))
            },
            items: viewModel.actions.primary.map(PhotosActionBarMapping.buttonViewModel(for:))
        )
        .padding(.bottom, 20)
        .dialogSheet(item: $viewModel.currentAction, model: viewModel.dialogModel)
        .safeAreaInset(edge: .bottom) {
            ColorProvider.BackgroundNorm
        }
        .ignoresSafeArea()
        .background(ColorProvider.BackgroundNorm)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            NotificationCenter.default.post(name: .actionBarVisibilityIsChanged, object: nil, userInfo: ["isVisible": true])
        }
        .onDisappear {
            NotificationCenter.default.post(name: .actionBarVisibilityIsChanged, object: nil, userInfo: ["isVisible": false])
        }
    }
}
