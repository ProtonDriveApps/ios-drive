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
import PDCore

final class PopulateCoordinator {
    private(set) unowned var viewController: PopulateViewController
    private let populatedViewControllerFactory: (NodeIdentifier) -> UIViewController
    private let onboardingViewControllerFactory: () -> UIViewController?

    public init(
        viewController: PopulateViewController,
        populatedViewControllerFactory: @escaping (NodeIdentifier) -> UIViewController,
        onboardingViewControllerFactory: @escaping () -> UIViewController?
    ) {
        self.viewController = viewController
        self.populatedViewControllerFactory = populatedViewControllerFactory
        self.onboardingViewControllerFactory = onboardingViewControllerFactory
    }

    func showPopulated(root: NodeIdentifier) {
        let populated = populatedViewControllerFactory(root)
        viewController.navigationController?.pushViewController(populated, animated: false)
        if let modal = onboardingViewControllerFactory() {
            viewController.present(modal, animated: true)
        }
    }
}
