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

public final class StartCoordinator {
    private weak var viewController: StartViewController!
    private var navigationController: UINavigationController? {
        viewController.navigationController
    }

    private let authenticatedViewControllerFactory: () -> UIViewController
    private let nonAuthenticatedViewControllerFactory: () -> UIViewController
    private let onboardingFactory: () -> UIViewController

    public init(
        viewController: StartViewController,
        authenticatedViewControllerFactory: @escaping () -> UIViewController,
        nonAuthenticatedViewControllerFactory: @escaping () -> UIViewController,
        onboardingFactory: @escaping () -> UIViewController
    ) {
        self.viewController = viewController
        self.authenticatedViewControllerFactory = authenticatedViewControllerFactory
        self.nonAuthenticatedViewControllerFactory = nonAuthenticatedViewControllerFactory
        self.onboardingFactory = onboardingFactory
    }

    func onAuthenticated() {
        push(authenticatedViewControllerFactory(), onto: viewController)
    }

    func onFirstTimeAuthenticated() {
        onAuthenticated()
        let onboardingViewController = onboardingFactory()
        viewController.present(onboardingViewController, animated: false)
    }

    func onNonAuthenticated() {
        push(nonAuthenticatedViewControllerFactory(), onto: viewController)
        viewController.dismiss(animated: false)
    }

    private func push(_ vc: UIViewController, onto root: UIViewController) {
        navigationController?.setViewControllers([root, vc], animated: false)
    }
}
