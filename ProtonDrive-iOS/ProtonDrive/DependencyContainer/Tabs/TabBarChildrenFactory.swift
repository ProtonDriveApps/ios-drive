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

import Combine
import PDCore
import PDCoreIOS
import UIKit

protocol TabBarChildrenFactoryProtocol {
    func makeChildren() -> [UIViewController]
}

final class TabBarChildrenFactory: TabBarChildrenFactoryProtocol {
    private let visibilityPolicy: VisibilityPolicy
    private let makeFilesViewControllerFactory: () -> UIViewController
    private let makePhotosViewController: () -> UIViewController
    private let makeSharedViewController: () -> UIViewController
    private let makeSharedWithMeViewController: () -> UIViewController
    private let makeComputersViewController: () -> UIViewController

    init(
        visibilityPolicy: VisibilityPolicy,
        makeFilesViewControllerFactory: @escaping () -> UIViewController,
        makePhotosViewController: @escaping () -> UIViewController,
        makeSharedViewController: @escaping () -> UIViewController,
        makeSharedWithMeViewController: @escaping () -> UIViewController,
        makeComputersViewController: @escaping () -> UIViewController
    ) {
        self.visibilityPolicy = visibilityPolicy
        self.makeFilesViewControllerFactory = makeFilesViewControllerFactory
        self.makePhotosViewController = makePhotosViewController
        self.makeSharedViewController = makeSharedViewController
        self.makeSharedWithMeViewController = makeSharedWithMeViewController
        self.makeComputersViewController = makeComputersViewController
    }

    func makeChildren() -> [UIViewController] {
        var viewControllers: [UIViewController] = []

        // My Files is always shown
        viewControllers.append(makeFilesViewControllerFactory())

        // Photos tab
        if visibilityPolicy.shouldShow(.photosTab) {
            viewControllers.append(makePhotosViewController())
        }

        // Computers tab
        if visibilityPolicy.shouldShow(.computersTab) {
            viewControllers.append(makeComputersViewController())
        }

        // Sharing tabs (mutually exclusive)
        if visibilityPolicy.shouldShow(.sharedWithMeTab) {
            viewControllers.append(makeSharedWithMeViewController())
        } else if visibilityPolicy.shouldShow(.sharedTab) {
            viewControllers.append(makeSharedViewController())
        }

        return viewControllers
    }
}
