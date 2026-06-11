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
import ProtonCoreAccountRecovery
import ProtonCoreServices

final class LaunchCoordinator {
    private let window: UIWindow
    private let networkService: PMAPIService
    private weak var viewController: LaunchViewController!
    private let startViewControllerFactory: () -> UIViewController
    private let failingAlertFactory: (FailingAlert) -> UIViewController

    public init(
        window: UIWindow,
        networkService: PMAPIService,
        viewController: LaunchViewController,
        startViewControllerFactory: @escaping () -> UIViewController,
        failingAlertFactory: @escaping (FailingAlert) -> UIViewController
    ) {
        self.window = window
        self.networkService = networkService
        self.viewController = viewController
        self.startViewControllerFactory = startViewControllerFactory
        self.failingAlertFactory = failingAlertFactory

        window.rootViewController = viewController
    }

    func launchApp() {
        let launcher = startViewControllerFactory()
        for child in viewController.children {
            child.remove()
        }
        viewController.add(launcher)
    }

    func presentAlert(alert: FailingAlert) {
        UIApplication.shared.rootViewController()?.presentedViewController?.dismiss(
            animated: false,
            completion: { [weak self] in
                // Show login view again
                self?.launchApp()
                self?.present(alert: alert, withDelay: 1)
            }
        ) // dismiss active modals, if any
    }
    
    private func present(alert: FailingAlert, withDelay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + withDelay) { [weak self] in
            guard let self else { return }
            let vc = self.failingAlertFactory(alert)
            UIApplication.shared.topViewController()?.present(vc, animated: true, completion: nil)
        }
    }

    func presentAccountRecovery(apiService: APIService) {
        let accountRecoveryViewController = AccountRecoveryModule.settingsViewController(
            apiService
        ) { _ in }
        UIApplication.shared.topViewController()?.present(accountRecoveryViewController, animated: true)
    }

    func presentReportIssue() {
        let target = [
            "ProtonCoreLoginUI.WelcomeViewController",
            "ProtonCoreLoginUI.LoginViewController",
            "ProtonCoreLoginUI.SignupViewController"
        ]
        guard let topVC = UIApplication.shared.topViewController() else { return }
        let isTargetView = target.contains(where: { String(describing: topVC).contains($0) })
        guard isTargetView || isPopulateView(topVC: topVC) else { return }

        let factory = BugReportFactory(apiService: networkService, sessionVault: nil)
        let reportVC = factory.makeBugReportViewController()
        topVC.present(reportVC, animated: true)
    }

    private func isPopulateView(topVC: UIViewController) -> Bool {
        guard
            let nav = topVC.children.compactMap({ $0 as? UINavigationController }).first,
            let protectVC = nav.viewControllers.compactMap({ $0 as? ProtectViewController }).first,
            let protectNav = protectVC.children.first as? UINavigationController,
            protectNav.viewControllers.count == 1,
            protectNav.viewControllers.contains(where: { $0 is PopulateViewController })
        else { return false }
        return true
    }
}
