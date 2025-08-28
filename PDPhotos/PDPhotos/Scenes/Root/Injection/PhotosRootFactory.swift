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

import PDCore
import SwiftUI
import UIKit
import PDUIComponents

struct PhotosRootFactory {
    func makeViewController(
        container: PDPhotosContainer,
        configuration: PhotosRootConfiguration
    ) -> UIViewController {
        let userInfoController = UserInfoControllerFactory()
            .makeController(sessionVault: container.dependencies.tower.sessionVault)
        let bootstrapController = container.bootstrapController
        let coordinator = PhotosCoordinator(container: container)
        let viewModel = PhotosRootViewModel(
            bootstrapController: bootstrapController,
            selectionController: LocalPhotosSelectionController(),
            migrationController: container.migrationAvailableController,
            configuration: configuration,
            coordinator: coordinator,
            featureFlagsController: container.dependencies.featureFlagsController,
            userInfoController: userInfoController,
            localSettings: container.dependencies.tower.localSettings,
            tagsMigrationConstraintController: container.dependencies.tagsMigrationConstraint
        )
        let view = PhotosRootView(
            viewModel: viewModel,
            navigationFactory: PhotosRootNavigationButtonFactory(),
            gallery: { streamConfiguration in
                container.sceneContainer.makeGalleryView(
                    configuration: configuration,
                    rootViewController: coordinator.rootViewController,
                    selectionController: viewModel.selectionController,
                    streamConfiguration: streamConfiguration
                )
            },
            albums: { streamConfiguration in
                container.sceneContainer.makeAlbumsView(
                    configuration: configuration,
                    streamConfiguration: streamConfiguration,
                    rootViewController: coordinator.rootViewController
                )
            }
        )
        let rootView = RootView(vm: container.rootViewModel, activeArea: { view })
        let viewController = UIHostingController(rootView: rootView)
        coordinator.rootViewController = viewController
        return viewController
    }
}
