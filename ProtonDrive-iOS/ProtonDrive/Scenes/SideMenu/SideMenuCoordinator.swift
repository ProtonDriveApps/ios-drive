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

import Combine
import UIKit
import PMSideMenu
import PDCore
import PMSettings
import PDUIComponents
import ProtonCoreUIFoundations

final class SideMenuCoordinator {
    typealias Destination = MenuViewModel.Destination

    weak var delegate: PMSlidingContainer!
    weak var viewController: SideMenuViewController!
    private weak var settingsVC: UIViewController?
    private var cancellables: Set<AnyCancellable> = []

    private let ratingBoosterFlowController: RatingBoosterFlowControllerProtocol
    private let myFilesFactory: (DeepLinkNotification?) -> UIViewController
    private let sharedByMeFactory: (Deeplink?) -> UIViewController
    private let trashFactory: () -> UIViewController
    private let offlineAvailableFactory: () -> UIViewController
    private let settingsFactory: () -> UIViewController
    private let plansFactory: () -> UIViewController
    private let storageBonusPromoFactory: () -> UIViewController
    private let reportBugFactory: () -> UIViewController
    private let makeAccountSettingsSection: () -> PMSettingsSectionViewModel
    private let sceneInitStateController: SceneInitStateControllerProtocol

    init(
        viewController: SideMenuViewController,
        ratingBoosterFlowController: RatingBoosterFlowControllerProtocol,
        sceneInitStateController: SceneInitStateControllerProtocol,
        generalSettings: GeneralSettings,
        myFilesFactory: @escaping (DeepLinkNotification?) -> UIViewController,
        sharedByMeFactory: @escaping (Deeplink?) -> UIViewController,
        trashFactory: @escaping () -> UIViewController,
        offlineAvailableFactory: @escaping () -> UIViewController,
        settingsFactory: @escaping () -> UIViewController,
        plansFactory: @escaping () -> UIViewController,
        storageBonusPromoFactory: @escaping () -> UIViewController,
        reportBugFactory: @escaping () -> UIViewController,
        makeAccountSettingsSection: @escaping () -> PMSettingsSectionViewModel
    ) {
        self.viewController = viewController
        self.ratingBoosterFlowController = ratingBoosterFlowController
        self.sceneInitStateController = sceneInitStateController
        self.myFilesFactory = myFilesFactory
        self.sharedByMeFactory = sharedByMeFactory
        self.trashFactory = trashFactory
        self.offlineAvailableFactory = offlineAvailableFactory
        self.settingsFactory = settingsFactory
        self.plansFactory = plansFactory
        self.storageBonusPromoFactory = storageBonusPromoFactory
        self.reportBugFactory = reportBugFactory
        self.makeAccountSettingsSection = makeAccountSettingsSection

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receiveDeepLink(notification:)),
            name: .deepLink,
            object: nil
        )
        generalSettings.userSettings
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.generalSettingsDidUpdate()
            }
            .store(in: &cancellables)
    }

    func go(to destination: Destination, deepLinkNotification: DeepLinkNotification? = nil) {
        ratingBoosterFlowController.navigationDidHappen()
        switch destination {
        case .myFiles:
            showMyFiles(deepLinkNotification: deepLinkNotification)
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
            showSharedByMe(deepLinkNotification: deepLinkNotification)
        case .storageBonusPromo:
            showStorageBonusPromo()
        }
        sceneInitStateController.setSceneIsInited()
    }
}

private extension SideMenuCoordinator {
    func showMyFiles(deepLinkNotification: DeepLinkNotification?) {
        delegate.sideMenu(viewController, didSelectViewController: myFilesFactory(deepLinkNotification))
    }

    func showSharedByMe(deepLinkNotification: DeepLinkNotification?) {
        var deepLink: Deeplink?
        if let deepLinkNotification, deepLinkNotification.menuDestination == .sharedByMe {
            deepLink = deepLinkNotification.link
        }
        delegate.sideMenu(viewController, didSelectViewController: sharedByMeFactory(deepLink))
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

    func showStorageBonusPromo() {
        let vc = storageBonusPromoFactory()
        vc.modalPresentationStyle = .fullScreen
        viewController.present(vc, animated: true)
    }

    func showFeedback() {
        let vc = reportBugFactory()
        vc.modalPresentationStyle = .fullScreen
        viewController.present(vc, animated: true)
    }

    func showLogout() {
        let vm = LogoutAlertViewModel()
        let optionMenu = UIAlertController(
            title: vm.title,
            message: vm.message,
            preferredStyle: .actionSheet
        )

        let logout = UIAlertAction(title: vm.logoutButton, style: .destructive, handler: { _ in vm.startUserInitiatedLogout() })
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

    @objc
    private func receiveDeepLink(notification: Notification) {
        guard let obj = notification.object as? DeepLinkNotification else { return }
        go(to: obj.menuDestination, deepLinkNotification: obj)
    }

    private func generalSettingsDidUpdate() {
        guard
            let nav = settingsVC as? DarkModeAwareNavigationViewController,
            let vc = nav.viewControllers.first as? PMSettingsViewController
        else { return }
        let section = makeAccountSettingsSection()
        vc.viewModel.update(section: section)

        if nav.viewControllers.count >= 2,
           nav.viewControllers[1] is ShowingNavigationBarUIHostingController {
            // Only sign in with QR code use `ShowingNavigationBarUIHostingController`
            nav.popToViewController(vc, animated: true)
        }
    }
}

extension PMSlidingContainer {
    func sideMenu(_ sideMenuViewController: SideMenuViewController, didSelectViewController viewController: UIViewController) {
        setContent(to: viewController)
    }
}
