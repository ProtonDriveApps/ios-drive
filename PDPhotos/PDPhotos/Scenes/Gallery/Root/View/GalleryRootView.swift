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

import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI
import PDCoreIOS

struct GalleryRootView<
    ViewModel: GalleryRootViewModelProtocol,
    OnboardingView: View,
    PermissionsView: View,
    GalleryView: View
>: View {
    @ObservedObject private var viewModel: ViewModel
    private let onboarding: () -> OnboardingView
    private let permissions: () -> PermissionsView
    private let galleryView: GalleryView

    init(
        viewModel: ViewModel,
        onboarding: @escaping () -> OnboardingView,
        permissions: @escaping () -> PermissionsView,
        galleryView: GalleryView
    ) {
        self.viewModel = viewModel
        self.onboarding = onboarding
        self.permissions = permissions
        self.galleryView = galleryView
    }

    var body: some View {
        content
            .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
            .onAppear {
                viewModel.updateVisibleStatus(isVisible: true)
                viewModel.refreshIfNeeded()
            }
            .onDisappear(perform: {
                viewModel.updateVisibleStatus(isVisible: false)
            })
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                guard viewModel.isVisible else { return }
                viewModel.refreshIfNeeded()
            }
    }

    @ViewBuilder
    private var upgradeHintBanner: some View {
        let level = viewModel.upgradeRequirementLevel
        if let handling = viewModel.upgradeRequirementHandling {
            UpgradeRequirementBannerView(level: level, handling: handling)
        }
    }

    @ViewBuilder
    private var content: some View {
        upgradeHintBanner
        switch viewModel.state {
        case .disconnection:
            NoConnectionView(isUpdating: .constant(false), config: .noConnectionInPhoto) { [weak viewModel] in
                viewModel?.refreshIfNeeded()
            }
        case .loading:
            VStack {
                Spacer()
                ProtonSpinner(size: .medium, style: .regular)
                Spacer()
            }
        case .onboarding:
            onboarding()
        case .permissions:
            permissions()
        case .gallery:
            galleryView
        }
    }
}
