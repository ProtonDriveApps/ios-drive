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
import UIKit
import ProtonCoreUIFoundations

final class TabBarViewControllerFactory {
    static let filesTabTag = 0
    static let photosTabTag = 1
    static let sharedTabTag = 3
    
    func configureFilesTab(in controller: UIViewController) {
        controller.tabBarItem.title = "Files"
        controller.tabBarItem.image = IconProvider.folder
        controller.tabBarItem.selectedImage = IconProvider.folder
        controller.tabBarItem.accessibilityIdentifier = "TabBarViewControllerFactory.tabBarItem.Files"
        controller.tabBarItem.tag = Self.filesTabTag
    }

    func configureSharedTab(in controller: UIViewController) {
        controller.tabBarItem.title = "Shared"
        controller.tabBarItem.image = IconProvider.link
        controller.tabBarItem.selectedImage = IconProvider.link
        controller.tabBarItem.accessibilityIdentifier = "TabBarViewControllerFactory.tabBarItem.Shared"
        controller.tabBarItem.tag = Self.sharedTabTag
    }

    func configurePhotosTab(in controller: UIViewController) {
        controller.tabBarItem.title = "Photos"
        controller.tabBarItem.image = IconProvider.image
        controller.tabBarItem.selectedImage = IconProvider.image
        controller.tabBarItem.accessibilityIdentifier = "TabBarViewControllerFactory.tabBarItem.Photos"
        controller.tabBarItem.tag = Self.photosTabTag
    }
    
    func makeTabBarController(container: AuthenticatedDependencyContainer, children: [UIViewController]) -> UITabBarController {
        #if HAS_PHOTOS
        let coordinator = ConcreteTabBarCoordinator(photosContainer: container.photosContainer)
        let photosTabController = ConcretePhotosTabVisibleController(resource: container.tower.featureFlags)
        let viewModel = ConcreteTabsViewModel(photosTabController: photosTabController, coordinator: coordinator)
        let tabBarController = HidableTabBarController(viewModel: viewModel, children: children)
        coordinator.tabBarController = tabBarController
        #else
        let tabBarController = HidableTabBarController(viewModel: BlankTabsViewModel(), children: children)
        #endif
        viewModel.start()

        let tabBarAppearance: UITabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = ColorProvider.BackgroundNorm

        UITabBar.appearance().tintColor = ColorProvider.BrandNorm
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        return tabBarController
    }
}
