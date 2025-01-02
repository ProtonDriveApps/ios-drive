// Copyright (c) 2024 Proton AG
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

protocol TabBarChildrenFactoryProtocol {
    func makeChildren() -> [UIViewController]
}

final class TabBarChildrenFactory: TabBarChildrenFactoryProtocol {
    private let featureFlagsController: FeatureFlagsController
    private let makeFilesViewControllerFactory: () -> UIViewController
    private let makePhotosViewController: () -> UIViewController
    private let makeSharedViewController: () -> UIViewController
    private let makeSharedWithMeViewController: () -> UIViewController

    init(
        featureFlagsController: FeatureFlagsController,
        makeFilesViewControllerFactory: @escaping () -> UIViewController,
        makePhotosViewController: @escaping () -> UIViewController,
        makeSharedViewController: @escaping () -> UIViewController,
        makeSharedWithMeViewController: @escaping () -> UIViewController
    ) {
        self.featureFlagsController = featureFlagsController
        self.makeFilesViewControllerFactory = makeFilesViewControllerFactory
        self.makePhotosViewController = makePhotosViewController
        self.makeSharedViewController = makeSharedViewController
        self.makeSharedWithMeViewController = makeSharedWithMeViewController
    }

    public func makeChildren() -> [UIViewController] {
        var viewControllers: [UIViewController] = []

        let myFilesViewController = makeFilesViewControllerFactory()
        viewControllers.append(myFilesViewController)

        let photosViewController = makePhotosViewController()
        viewControllers.append(photosViewController)

        if featureFlagsController.hasSharing {
            let sharedWithMeViewController = makeSharedWithMeViewController()
            viewControllers.append(sharedWithMeViewController)
        } else {
            let sharedViewController = makeSharedViewController()
            viewControllers.append(sharedViewController)
        }

        return viewControllers
    }
}
