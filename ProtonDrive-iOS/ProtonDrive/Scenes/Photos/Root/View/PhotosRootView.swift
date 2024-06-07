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
import ProtonCoreUIFoundations
import SwiftUI

struct PhotosRootView<
    ViewModel: PhotosRootViewModelProtocol,
    OnboardingView: View,
    PermissionsView: View,
    GalleryView: View
>: View {
    @EnvironmentObject var root: RootViewModel
    @ObservedObject private var viewModel: ViewModel
    private let onboarding: () -> OnboardingView
    private let permissions: () -> PermissionsView
    private let galleryView: GalleryView

    init(viewModel: ViewModel, onboarding: @escaping () -> OnboardingView, permissions: @escaping () -> PermissionsView, galleryView: GalleryView) {
        self.viewModel = viewModel
        self.onboarding = onboarding
        self.permissions = permissions
        self.galleryView = galleryView
    }

    var body: some View {
        NavigatingView(
            title: viewModel.navigation.title,
            leading: button(with: viewModel.navigation.leftItem).any(),
            trailing: viewModel.navigation.rightItem.map(button)?.any()
        ) {
            content
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
        .onReceive(root.closeCurrentSheet) { _ in
            viewModel.close()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .onboarding:
            onboarding()
        case .permissions:
            permissions()
        case .gallery:
            galleryView
        }
    }

    @ViewBuilder
    private func button(with item: PhotosRootNavigation.Item) -> any View {
        switch item {
        case .menu:
            MenuButton {
                viewModel.handle(item: item)
            }
        case let .cancel(title):
            TextNavigationBarButton(title: title, weight: .bold) {
                viewModel.handle(item: item)
            }
            .accessibility(identifier: "PhotosRootView.NavigationBarButton.Cancel")
        case let .selection(title):
            TextNavigationBarButton(title: title) {
                viewModel.handle(item: item)
            }
            .accessibility(identifier: "PhotosRootView.NavigationBarButton.Selection")
        }
    }
}
