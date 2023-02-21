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
import PMSideMenu

final class SideMenuCoordinator {
    typealias Destination = MenuViewModel.Destination

    weak var delegate: PMSlidingContainer!
    weak var viewController: SideMenuViewController!

    private let myFilesFactory: () -> UIViewController
    private let trashFactory: () -> UIViewController
    private let offlineAvailableFactory: () -> UIViewController
    private let settingsFactory: () -> UIViewController
    private let accountFactory: () -> UIViewController
    private let plansFactory: () -> UIViewController

    init(
        viewController: SideMenuViewController,
        myFilesFactory: @escaping () -> UIViewController,
        trashFactory: @escaping () -> UIViewController,
        offlineAvailableFactory: @escaping () -> UIViewController,
        settingsFactory: @escaping () -> UIViewController,
        accountFactory: @escaping () -> UIViewController,
        plansFactory: @escaping () -> UIViewController
    ) {
        self.viewController = viewController
        self.myFilesFactory = myFilesFactory
        self.trashFactory = trashFactory
        self.offlineAvailableFactory = offlineAvailableFactory
        self.settingsFactory = settingsFactory
        self.accountFactory = accountFactory
        self.plansFactory = plansFactory
    }

    func go(to destination: Destination) {
        switch destination {
        case .myFiles:
            showMyFiles()
        case .servicePlans:
            showServicePlans()
        case .accountManager:
            showAccountManager()
        case .trash:
            showTrash()
        case .offlineAvailable:
            showAvailableOffline()
        case .settings:
            showSettings()
        case .feedback:
            showFeedback()
        case .logout:
            showLogout()
        }
    }
}

private extension SideMenuCoordinator {
    func showMyFiles() {
        delegate.sideMenu(viewController, didSelectViewController: myFilesFactory())
    }

    func showServicePlans() {
        delegate.sideMenu(viewController, didSelectViewController: plansFactory())
    }

    func showTrash() {
        delegate.sideMenu(viewController, didSelectViewController: trashFactory())
    }

    func showAccountManager() {
        let vc = accountFactory()
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        vc.view.backgroundColor = .clear
        viewController.present(vc, animated: false, completion: nil)
    }

    func showSettings() {
        delegate.sideMenu(viewController, didSelectViewController: settingsFactory())
    }

    func showAvailableOffline() {
        delegate.sideMenu(viewController, didSelectViewController: offlineAvailableFactory())
    }

    func showFeedback() {
        UIApplication.shared.open(Constants.reportBugURL, options: [:], completionHandler: nil)
    }

    func showLogout() {
        let vm = LogoutAlertViewModel()
        let optionMenu = UIAlertController(
            title: vm.title,
            message: vm.message,
            preferredStyle: .actionSheet
        )

        let logout = UIAlertAction(title: vm.logoutButton, style: .destructive, handler: { _ in vm.requestLogout() })
        logout.accessibilityIdentifier = "SideMenu.logOut"
        let cancel = UIAlertAction(title: vm.cancelButton, style: .cancel, handler: nil)

        optionMenu.addAction(logout)
        optionMenu.addAction(cancel)
        optionMenu.popoverPresentationController?.sourceView = viewController.view
        optionMenu.popoverPresentationController?.sourceRect = viewController.view.frame
        viewController.present(optionMenu, animated: true, completion: nil)
    }
}

extension PMSlidingContainer {
    func sideMenu(_ sideMenuViewController: SideMenuViewController, didSelectViewController viewController: UIViewController) {
        setContent(to: viewController)
    }
}
