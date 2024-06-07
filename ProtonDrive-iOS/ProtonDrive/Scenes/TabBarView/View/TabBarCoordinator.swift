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

protocol TabBarCoordinator {
    func showPhotosTab()
    func hidePhotosTab()
}

final class ConcreteTabBarCoordinator: TabBarCoordinator {
    weak var tabBarController: UITabBarController?
    weak var photosContainer: PhotosContainer?

    init(photosContainer: PhotosContainer?) {
        self.photosContainer = photosContainer
    }

    func showPhotosTab() {
        var children = tabBarController?.viewControllers ?? []

        guard children.count == 2 else {
            return
        }

        guard let photosViewController = makePhotosViewController() else {
            return
        }

        children.insert(photosViewController, at: 1)
        tabBarController?.setViewControllers(children, animated: false)
    }
    
    func hidePhotosTab() {
        var children = tabBarController?.viewControllers ?? []

        guard let index = children.firstIndex(where: { $0.tabBarItem.tag == TabBarViewControllerFactory.photosTabTag }) else {
            return
        }
        
        children.remove(at: index)
        tabBarController?.setViewControllers(children, animated: false)
    }

    private func makePhotosViewController() -> UIViewController? {
        guard let photosViewController = photosContainer?.makeRootViewController() else {
            return nil
        }

        let factory = TabBarViewControllerFactory()
        factory.configurePhotosTab(in: photosViewController)
        return photosViewController
    }
}
