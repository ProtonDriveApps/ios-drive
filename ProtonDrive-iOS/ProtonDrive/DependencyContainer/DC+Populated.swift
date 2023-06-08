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

import PDCore
import UIKit
import SwiftUI
import PDUIComponents
import ProtonCore_Settings
import ProtonCore_Services
import ProtonCore_HumanVerification
import ProtonCore_Payments
import PMSideMenu

extension AuthenticatedDependencyContainer {
    func makeHomeViewController(root: NodeIdentifier) -> UIViewController {
        makeSlidingViewController(root: root)
    }

    func makeSlidingViewController(root: NodeIdentifier) -> UIViewController {
        let sideMenuViewController = makeSideMenuViewController()
        let sideMenuCoordinator = makeSideMenuCoordinator(sideMenuViewController, root: root)
        let slidingViewController = PMSlidingContainerComposer.makePMSlidingContainer(skeleton: UIViewController(),
                                                                                      menu: sideMenuViewController,
                                                                                      togglePublisher: DriveNotification.toggleSideMenu.publisher)
        
        sideMenuCoordinator.delegate = slidingViewController
        sideMenuViewController.onMenuDidSelect = sideMenuCoordinator.go(to:)
        slidingViewController.onMenuToggle = { isMenuOpen in
            UIApplication.setStatusBarStyle(isMenuOpen ? .lightContent : .default)
        }

        return slidingViewController
    }

    private func makeSideMenuViewController() -> SideMenuViewController {
        let menuModel = MenuModel(sessionVault: tower.sessionVault)
        let menuViewModel = MenuViewModel(model: menuModel, offlineSaver: tower.offlineSaver)
        return SideMenuViewController(menuViewModel: menuViewModel)
    }

    private func makeSideMenuCoordinator(_ viewController: SideMenuViewController, root: NodeIdentifier) -> SideMenuCoordinator {
        SideMenuCoordinator(
            viewController: viewController,
            myFilesFactory: { self.makeMyFilesViewControllerFactory(root: root) },
            trashFactory: makeTrashViewController,
            offlineAvailableFactory: makeOfflineAvailableViewController,
            settingsFactory: makeSettingsViewController,
            accountFactory: makeAccountViewController,
            plansFactory: makePlansViewController
        )
    }

    private func makeAccountViewController() -> UIViewController {
        assertionFailure("This screen was pulled out from MVP, will be replaced by Core implementation in future")
        return UIViewController()
    }
    
    private func makeMyFilesViewControllerFactory(root: NodeIdentifier) -> UIViewController {
        let myFilesViewController = makeFilesViewControllerFactory(root: root)
        factory.configureFilesTab(in: myFilesViewController)
        
        let sharedViewController = makeSharedViewController(root: root)
        factory.configureSharedTab(in: sharedViewController)

        var viewControllers = [myFilesViewController, sharedViewController]

        #if HAS_PHOTOS
            let photosViewController = photosContainer.makeRootViewController()
            factory.configurePhotosTab(in: photosViewController)
            viewControllers.insert(photosViewController, at: 1)
        #endif

        return factory.makeTabBarController(children: viewControllers)
    }

    private func makeFilesViewControllerFactory(root: NodeIdentifier) -> UIViewController {
        let coordinator = FinderCoordinator(tower: tower, photoPickerCoordinator: pickersContainer.getPhotoCoordinator())
        let rootFolderView = RootFolderView(nodeID: root, coordinator: coordinator).any()
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootFolderView })
        return UIHostingController(rootView: rootView)
    }
    
    private func makeSharedViewController(root: NodeIdentifier) -> UIViewController {
        let rootSharedView = RootSharedView(deeplink: nil, tower: tower, shareID: root.shareID)
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootSharedView })
        return UIHostingController(rootView: rootView)
    }

    private func makeTrashViewController() -> UIViewController {
        let trashView = TrashViewCoordinator().start(tower)
        let rootView = RootView(vm: RootViewModel(), activeArea: { trashView })
        let rootViewController = UIHostingController(rootView: rootView)
        return UINavigationController(rootViewController: rootViewController)
    }

    private func makeOfflineAvailableViewController() -> UIViewController {
        let rootOfflineAvailableView = RootOfflineAvailableView(deeplink: nil, tower: tower)
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootOfflineAvailableView })
        return UIHostingController(rootView: rootView)
    }

    private func makePlansViewController() -> UIViewController {
        let payments = Payments(
            inAppPurchaseIdentifiers: Constants.drivePlanIDs,
            apiService: networkService,
            localStorage: tower.paymentsStorage,
            reportBugAlertHandler: nil
        )
        let viewController = SubscriptionViewController(
            isUnlocked: !keymaker.isLocked(),
            isSignedIn: tower.sessionVault.isSignedIn(),
            userId: tower.sessionVault.clientCredential()?.userID,
            activeUsername: tower.sessionVault.getAccountInfo()?.displayName,
            payments: payments
        )
        let navigationController = UINavigationController(rootViewController: viewController)
        return navigationController
    }

    private func makeSettingsViewController() -> UIViewController {
        SettingsAssembler.assemble(apiService: networkService, tower: tower, keymaker: keymaker)
    }
}
