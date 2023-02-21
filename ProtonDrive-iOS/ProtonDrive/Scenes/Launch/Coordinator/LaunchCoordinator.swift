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
import Combine

final class LaunchCoordinator {
    private let window: UIWindow
    private weak var viewController: LaunchViewController!
    private let startViewControllerFactory: () -> UIViewController
    private let failingAlertFactory: (FailingAlert) -> UIViewController

    public init(
        window: UIWindow,
        viewController: LaunchViewController,
        startViewControllerFactory: @escaping () -> UIViewController,
        failingAlertFactory: @escaping (FailingAlert) -> UIViewController
    ) {
        self.window = window
        self.viewController = viewController
        self.startViewControllerFactory = startViewControllerFactory
        self.failingAlertFactory = failingAlertFactory

        window.rootViewController = viewController
    }

    func launchApp() {
        let launcher = startViewControllerFactory()
        viewController.add(launcher)
    }

    func presentAlert(alert: FailingAlert) {
        let vc = failingAlertFactory(alert)
        let topController = UIApplication.shared.topViewController()
        topController?.present(vc, animated: true, completion: nil)
    }
}
