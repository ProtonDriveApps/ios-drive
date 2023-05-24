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

import PDUIComponents
import ProtonCore_UIFoundations
import SwiftUI

struct PhotosRootView<
    ViewModel: PhotosRootViewModelProtocol,
    OnboardingView: View,
    PermissionsView: View,
    GalleryView: View
>: View {
    @ObservedObject private var viewModel: ViewModel
    private let onboarding: () -> OnboardingView
    private let permissions: () -> PermissionsView
    private let gallery: () -> GalleryView

    init(viewModel: ViewModel, onboarding: @escaping () -> OnboardingView, permissions: @escaping () -> PermissionsView, gallery: @escaping () -> GalleryView) {
        self.viewModel = viewModel
        self.onboarding = onboarding
        self.permissions = permissions
        self.gallery = gallery
    }

    var body: some View {
        ZStack {
            content
                .flatNavigationBar(viewModel.title, leading: menuButton, trailing: EmptyView())
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .onboarding:
            onboarding()
        case .permissions:
            permissions()
        case .gallery:
            gallery()
        }
    }

    private var menuButton: some View {
        MenuButton(action: viewModel.openMenu)
    }
}
