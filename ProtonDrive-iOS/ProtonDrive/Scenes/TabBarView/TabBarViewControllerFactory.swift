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

import UIKit
import ProtonCore_UIFoundations

final class TabBarViewControllerFactory {
    func configureFilesTab(in controller: UIViewController) {
        controller.tabBarItem.title = "Files"
        controller.tabBarItem.image = IconProvider.folder
        controller.tabBarItem.selectedImage = IconProvider.folder
        controller.tabBarItem.accessibilityIdentifier = "TabBarViewControllerFactory.tabBarItem.Files"
    }

    func configureSharedTab(in controller: UIViewController) {
        controller.tabBarItem.title = "Shared"
        controller.tabBarItem.image = IconProvider.link
        controller.tabBarItem.selectedImage = IconProvider.link
        controller.tabBarItem.accessibilityIdentifier = "TabBarViewControllerFactory.tabBarItem.Shared"
    }

    func configurePhotosTab(in controller: UIViewController) {
        controller.tabBarItem.title = "Photos"
        controller.tabBarItem.image = IconProvider.image
        controller.tabBarItem.selectedImage = IconProvider.image
        controller.tabBarItem.accessibilityIdentifier = "TabBarViewControllerFactory.tabBarItem.Photos"
    }
    
    func makeTabBarController(children: [UIViewController]) -> UIViewController {
        let tabBarController = HidableTabBarController()
        children.forEach(tabBarController.addChild)

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
