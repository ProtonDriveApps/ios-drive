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
    private weak var settingsVC: UIViewController?

    private let myFilesFactory: () -> UIViewController
    private let sharedByMeFactory: () -> UIViewController
    private let trashFactory: () -> UIViewController
    private let offlineAvailableFactory: () -> UIViewController
    private let settingsFactory: () -> UIViewController
    private let plansFactory: () -> UIViewController

    init(
        viewController: SideMenuViewController,
        myFilesFactory: @escaping () -> UIViewController,
        sharedByMeFactory: @escaping () -> UIViewController,
        trashFactory: @escaping () -> UIViewController,
        offlineAvailableFactory: @escaping () -> UIViewController,
        settingsFactory: @escaping () -> UIViewController,
        plansFactory: @escaping () -> UIViewController
    ) {
        self.viewController = viewController
        self.myFilesFactory = myFilesFactory
        self.sharedByMeFactory = sharedByMeFactory
        self.trashFactory = trashFactory
        self.offlineAvailableFactory = offlineAvailableFactory
        self.settingsFactory = settingsFactory
        self.plansFactory = plansFactory

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    func go(to destination: Destination) {
        switch destination {
        case .myFiles:
            showMyFiles()
        case .servicePlans:
            showServicePlans()
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
        case .sharedByMe:
            showSharedByMe()
        }
    }
}

private extension SideMenuCoordinator {
    func showMyFiles() {
        delegate.sideMenu(viewController, didSelectViewController: myFilesFactory())
    }

    func showSharedByMe() {
        delegate.sideMenu(viewController, didSelectViewController: sharedByMeFactory())
    }

    func showServicePlans() {
        delegate.sideMenu(viewController, didSelectViewController: plansFactory())
    }

    func showTrash() {
        delegate.sideMenu(viewController, didSelectViewController: trashFactory())
    }

    func showSettings() {
        let newVC = settingsFactory()
        settingsVC = newVC
        delegate.sideMenu(viewController, didSelectViewController: newVC)
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

    @objc
    func orientationDidChange() {
        guard
            settingsVC != nil, // Make sure setting view is presented
            let topVC = UIApplication.shared.topViewController(),
            let popover = topVC.presentationController as? UIPopoverPresentationController,
            let screenSize = topVC.view.realScreenSize()
        else { return }
        let point = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        popover.sourceRect = CGRect(origin: point, size: .zero)
    }
}

extension PMSlidingContainer {
    func sideMenu(_ sideMenuViewController: SideMenuViewController, didSelectViewController viewController: UIViewController) {
        setContent(to: viewController)
    }
}
