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
    private let deepLink: DeepLinkNotification?
    private let makeFilesViewControllerFactory: (Deeplink?) -> UIViewController
    private let makePhotosViewController: (Deeplink?) -> UIViewController
    private let makeSharedViewController: (Deeplink?) -> UIViewController
    private let makeSharedWithMeViewController: (Deeplink?) -> UIViewController
    private let makeComputersViewController: (Deeplink?) -> UIViewController

    init(
        visibilityPolicy: VisibilityPolicy,
        deepLink: DeepLinkNotification?,
        makeFilesViewControllerFactory: @escaping (Deeplink?) -> UIViewController,
        makePhotosViewController: @escaping (Deeplink?) -> UIViewController,
        makeSharedViewController: @escaping (Deeplink?) -> UIViewController,
        makeSharedWithMeViewController: @escaping (Deeplink?) -> UIViewController,
        makeComputersViewController: @escaping (Deeplink?) -> UIViewController
    ) {
        self.visibilityPolicy = visibilityPolicy
        self.deepLink = deepLink
        self.makeFilesViewControllerFactory = makeFilesViewControllerFactory
        self.makePhotosViewController = makePhotosViewController
        self.makeSharedViewController = makeSharedViewController
        self.makeSharedWithMeViewController = makeSharedWithMeViewController
        self.makeComputersViewController = makeComputersViewController
    }

    func makeChildren() -> [UIViewController] {
        var viewControllers: [UIViewController] = []
        // My Files is always shown
        viewControllers.append(makeFilesViewControllerFactory(deepLink(for: .files)))

        // Photos tab
        if visibilityPolicy.shouldShow(.photosTab) {
            viewControllers.append(makePhotosViewController(deepLink(for: .photos)))
        }

        // Computers tab
        if visibilityPolicy.shouldShow(.computersTab) {
            viewControllers.append(makeComputersViewController(deepLink(for: .computers)))
        }

        // Sharing tabs (mutually exclusive)
        if visibilityPolicy.shouldShow(.sharedWithMeTab) {
            viewControllers.append(makeSharedWithMeViewController(deepLink(for: .sharedWithMe)))
        } else if visibilityPolicy.shouldShow(.sharedTab) {
            viewControllers.append(makeSharedViewController(deepLink(for: .shared)))
        }

        return viewControllers
    }

    private func deepLink(for tab: TabBarItem) -> Deeplink? {
        guard let deepLink, let linkTab = deepLink.tab else { return nil }
        return tab.tag == linkTab.tag ? deepLink.link : nil
    }
}
