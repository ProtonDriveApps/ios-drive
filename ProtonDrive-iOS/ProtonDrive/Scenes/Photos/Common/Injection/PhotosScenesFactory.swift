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

import PDCore
import SwiftUI
import UIKit

struct PhotosScenesFactory {
    func makeRootPhotosViewController(settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController) -> UIViewController {
        let coordinator = PhotosCoordinator()
        let viewModel = PhotosRootViewModel(coordinator: coordinator, settingsController: settingsController, authorizationController: authorizationController)
        let view = PhotosRootView(
            viewModel: viewModel,
            onboarding: {
                PhotosOnboardingView(viewModel: PhotosOnboardingViewModel(settingsController: settingsController, authorizationController: authorizationController))
            },
            permissions: {
                makePermissionsView(coordinator: coordinator)
            },
            gallery: {
                makeGalleryView()
            }
        )
        return UIHostingController(rootView: view)
    }

    private func makePermissionsView(coordinator: PhotosPermissionsCoordinator) -> some View {
        let viewModel = PhotosPermissionsViewModel(coordinator: coordinator)
        return PhotosPermissionsView(viewModel: viewModel)
    }

    private func makeGalleryView() -> some View {
        PhotosGalleryView(viewModel: PhotosGalleryViewModel(), grid: makeGridView)
    }

    private func makeGridView() -> some View {
        let monthFormatter = LocalizedMonthFormatter(dateResource: PlatformDateResource(), dateFormatter: PlatformMonthAndYearFormatter(), monthResource: PlatformMonthResource())
        let viewModel = PhotosGridViewModel(
            controller: LocalPhotosGalleryController(),
            monthFormatter: monthFormatter,
            durationFormatter: LocalizedDurationFormatter()
        )
        return PhotosGridView(viewModel: viewModel) { item in
            PhotoItemView(viewModel: PhotoItemViewModel(item: item))
        }
    }
}
