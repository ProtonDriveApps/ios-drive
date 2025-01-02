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
import PMSettings
import ProtonCoreServices
import ProtonCoreHumanVerification
import ProtonCorePayments
import PMSideMenu
import ProtonCoreUIFoundations

extension AuthenticatedDependencyContainer {
    func makeHomeViewController() -> UIViewController {
        makeSlidingViewController()
    }

    func makeSlidingViewController() -> UIViewController {
        let sideMenuViewController = makeSideMenuViewController()
        let sideMenuCoordinator = makeSideMenuCoordinator(sideMenuViewController)
        let slidingViewController = PMSlidingContainerComposer.makePMSlidingContainer(
            skeleton: UIViewController(),
            menu: sideMenuViewController,
            togglePublisher: DriveNotification.toggleSideMenu.publisher
        )
        sideMenuCoordinator.delegate = slidingViewController
        sideMenuViewController.onMenuDidSelect = sideMenuCoordinator.go(to:)
        slidingViewController.onMenuToggle = { isMenuOpen in
            UIApplication.setStatusBarStyle(isMenuOpen ? .lightContent : .default)
        }

        return slidingViewController
    }

    private func makeSideMenuViewController() -> SideMenuViewController {
        guard let offlineSaver = tower.offlineSaver else { fatalError("offlineSaver must be non-nil in the iOS app") }

        let menuModel = MenuModel(sessionVault: tower.sessionVault)
        let menuViewModel = MenuViewModel(model: menuModel, offlineSaver: offlineSaver, featureFlagsController: featureFlagsController)
        return SideMenuViewController(menuViewModel: menuViewModel)
    }

    private func makeSideMenuCoordinator(_ viewController: SideMenuViewController) -> SideMenuCoordinator {
        SideMenuCoordinator(
            viewController: viewController,
            myFilesFactory: { self.makeTabBarViewControllerFactory() },
            sharedByMeFactory: makeSharedViewController,
            trashFactory: makeTrashViewController,
            offlineAvailableFactory: makeOfflineAvailableViewController,
            settingsFactory: makeSettingsViewController,
            plansFactory: makePlansViewController
        )
    }

    private func makeTabBarViewControllerFactory() -> UIViewController {
        let childrenFactory = makeChildrenFactory()
        let coordinator = TabBarCoordinator(childrenFactory: childrenFactory.makeChildren)
        let viewModel = TabBarViewModel(
            isTabBarHiddenPublisher: NotificationCenter.default.getPublisher(for: FinderNotifications.tabBar.name, publishing: Bool.self).eraseToAnyPublisher(),
            coordinator: coordinator,
            localSettings: tower.localSettings,
            volumeIdsController: tower.sharedVolumeIdsController,
            featureFlagsController: featureFlagsController
        )
        let tabBarController = HidableTabBarController(viewModel: viewModel, children: childrenFactory.makeChildren())
        coordinator.tabBarController = tabBarController
        return tabBarController
    }

    private func makeChildrenFactory() -> TabBarChildrenFactoryProtocol {
        return TabBarChildrenFactory(
            featureFlagsController: featureFlagsController,
            makeFilesViewControllerFactory: makeFilesViewControllerFactory,
            makePhotosViewController: makePhotosViewController,
            makeSharedViewController: makeSharedViewController,
            makeSharedWithMeViewController: makeSharedWithMeViewController
        )
    }

    private func makeFilesViewControllerFactory() -> UIViewController {
        let coordinator = FinderCoordinator(container: self, photoPickerCoordinator: pickersContainer.getPhotoCoordinator())
        let myFilesRootFetcher = MyFilesRootFetcher(storage: tower.storage)
        let rootFolderView = RootFolderView(nodeID: myFilesRootFetcher.getRoot(), coordinator: coordinator).any()
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootFolderView })
        let vc = UIHostingController(rootView: rootView)
        coordinator.rootViewController = vc
        configureForTabBar(vc, tabBarItem: .files)
        return vc
    }

    private func makePhotosViewController() -> UIViewController {
        let vc = photosContainer.makeRootViewController()
        configureForTabBar(vc, tabBarItem: .photos)
        return vc
    }

    private func makeSharedViewController() -> UIViewController {
        let coordinator = FinderCoordinator(container: self)
        let rootSharedView = RootSharedView(coordinator: coordinator)
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootSharedView })
        let vc = UIHostingController(rootView: rootView)
        coordinator.rootViewController = vc
        configureForTabBar(vc, tabBarItem: .shared)
        return vc
    }

    private func makeSharedWithMeViewController() -> UIViewController {
        let coordinator = FinderCoordinator(container: self, isSharedWithMe: true, photoPickerCoordinator: pickersContainer.getPhotoCoordinator())
        let view = RootSharedWithMeView(coordinator: coordinator)
        let rootView = RootView(vm: RootViewModel(), activeArea: { view })
        let vc = UIHostingController(rootView: rootView)
        configureForTabBar(vc, tabBarItem: .sharedWithMe)
        coordinator.rootViewController = vc
        return vc
    }

    private func makeTrashViewController() -> UIViewController {
        let trashView = TrashViewCoordinator().start(self)
        let rootView = RootView(vm: RootViewModel(), activeArea: { trashView })
        let rootViewController = UIHostingController(rootView: rootView)
        return UINavigationController(rootViewController: rootViewController)
    }

    private func makeOfflineAvailableViewController() -> UIViewController {
        let coordinator = FinderCoordinator(container: self)
        let rootOfflineAvailableView = RootOfflineAvailableView(coordinator: coordinator)
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootOfflineAvailableView })
        let vc = UIHostingController(rootView: rootView)
        coordinator.rootViewController = vc
        return vc
    }

    private func makePlansViewController() -> UIViewController {
        let dependencies = SubscriptionsContainer.Dependencies(tower: tower, keymaker: keymaker, networkService: networkService)
        let container = SubscriptionsContainer(dependencies: dependencies)
        let viewController = container.makeRootViewController()
        return MenuNavigationViewController(rootViewController: viewController)
    }

    @MainActor
    private func makeSettingsViewController() -> UIViewController {
        return SettingsAssembler.assemble(
            apiService: networkService,
            tower: tower,
            keymaker: keymaker,
            photosContainer: photosContainer.settingsContainer
        )
    }
}

extension AuthenticatedDependencyContainer {
    func configureForTabBar(_ viewController: UIViewController, tabBarItem: TabBarItem) {
        viewController.tabBarItem.title = tabBarItem.title
        viewController.tabBarItem.image = tabBarItem.icon
        viewController.tabBarItem.accessibilityIdentifier = tabBarItem.identifierInTabBar
        viewController.tabBarItem.tag = tabBarItem.tag
    }
}
