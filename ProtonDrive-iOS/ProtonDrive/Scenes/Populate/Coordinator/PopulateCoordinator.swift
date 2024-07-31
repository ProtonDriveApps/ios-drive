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

protocol PopulateCoordinatorProtocol {
    func showPopulated(root: NodeIdentifier)
}

final class PopulateCoordinator: PopulateCoordinatorProtocol {
    private(set) unowned var viewController: PopulateViewController
    private let populatedViewControllerFactory: (NodeIdentifier) -> UIViewController
    private let onboardingViewControllerFactory: () -> UIViewController?
    private let upsellFactory: () -> UIViewController?

    public init(
        viewController: PopulateViewController,
        populatedViewControllerFactory: @escaping (NodeIdentifier) -> UIViewController,
        onboardingViewControllerFactory: @escaping () -> UIViewController?,
        upsellFactory: @escaping () -> UIViewController?
    ) {
        self.viewController = viewController
        self.populatedViewControllerFactory = populatedViewControllerFactory
        self.onboardingViewControllerFactory = onboardingViewControllerFactory
        self.upsellFactory = upsellFactory
    }

    func showPopulated(root: NodeIdentifier) {
        let populated = populatedViewControllerFactory(root)
        viewController.navigationController?.pushViewController(populated, animated: false)
        if let modal = onboardingViewControllerFactory() {
            viewController.present(modal, animated: true)
        } else if let modal = upsellFactory() {
            viewController.present(modal, animated: true)
        }
    }
}
