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
import PDCore
import PDCoreIOS
import UIKit
import SwiftUI
import PDPhotos
import PDUIComponents
import PMSettings
import ProtonCoreServices
import ProtonCoreHumanVerification
import ProtonCorePayments
import PMSideMenu
import PDLocalization
import ProtonCoreUIFoundations
import ProtonCoreFeatureFlags

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
        sideMenuViewController.onMenuDidSelect = { [sideMenuCoordinator] destination in
            sideMenuCoordinator.go(to: destination)
        }
        slidingViewController.onMenuToggle = { isMenuOpen in
            UIApplication.setStatusBarStyle(isMenuOpen ? .lightContent : .default)
        }

        return slidingViewController
    }

    private func makeSideMenuViewController() -> SideMenuViewController {
        tower.subscribeToCleanUpNotifications()
        let showStorageInteractor = StorageBonusPromoFactory().makeShowStorageBonusPromoInteractor(tower: tower)
        let menuModel = MenuModel(sessionVault: tower.sessionVault)
        let menuViewModel = MenuViewModel(
            model: menuModel,
            offlineAvailableProgressProvider: OfflineSaversProgressProvider(offlineSavers: tower.offlineSavers),
            featureFlagsController: featureFlagsController,
            showStorageBonusPromoInteractor: showStorageInteractor,
            sdkFlags: getSDKMenuFlags(),
            localSettings: tower.localSettings
        )
        return SideMenuViewController(menuViewModel: menuViewModel)
    }
    
    private func getSDKMenuFlags() -> SDKMenuFlags {
        #if HAS_BETA_FEATURES
        let sdkFlags: [SDKMenuFlag] = [
            tower.getSdkFileUploader().isNotNil ? SDKMenuFlag.isUsingSDKMainVolumeUpload : nil,
            tower.getSdkPhotoUploader().isNotNil ? SDKMenuFlag.isUsingSDKPhotoVolumeUpload : nil,
            tower.getSdkFileDownloader().isNotNil ? SDKMenuFlag.isUsingSDKMainVolumeDownload : nil,
            tower.getSdkPhotoDownloader().isNotNil ? SDKMenuFlag.isUsingSDKPhotoVolumeDownload : nil,
            tower.getSdkThumbnailsDownloaderForFiles().isNotNil ? SDKMenuFlag.isUsingSDKMainVolumeThumbnails : nil,
            tower.getSdkThumbnailsDownloaderForPhotos().isNotNil ? SDKMenuFlag.isUsingSDKPhotoVolumeThumbnails : nil,
            tower.getSdkNodeOperationPerformer().isNotNil ? SDKMenuFlag.isUsingSDKNodeOperations : nil
        ].compactMap { $0 }
        return Set(sdkFlags)
        #else
        return []
        #endif
    }

    private func makeSideMenuCoordinator(_ viewController: SideMenuViewController) -> SideMenuCoordinator {
        return SideMenuCoordinator(
            viewController: viewController,
            ratingBoosterFlowController: ratingBoosterFlowController,
            sceneInitStateController: sceneInitStateController,
            generalSettings: tower.generalSettings,
            myFilesFactory: { self.makeTabBarViewControllerFactory(deepLink: $0) },
            sharedByMeFactory: { self.makeSharedViewController(deepLink: $0) },
            trashFactory: makeTrashViewController,
            offlineAvailableFactory: makeOfflineAvailableViewController,
            settingsFactory: makeSettingsViewController,
            plansFactory: makePlansViewController,
            storageBonusPromoFactory: makeStorageBonusPromoViewController,
            reportBugFactory: makeReportBugViewController,
            makeAccountSettingsSection: makeAccountSettingsSection
        )
    }

    private func makeTabBarViewControllerFactory(deepLink: DeepLinkNotification?) -> UIViewController {
        if let tabItem = TabBarItem(rawValue: tower.localSettings.defaultHomeTabTag) {
            tower.performanceMetricsController?.startRecord(pageType: tabItem.toMetricTag)
        }
        let childrenFactory = makeChildrenFactory(deepLink: deepLink)
        let coordinator = TabBarCoordinator(childrenFactory: childrenFactory.makeChildren)
        let viewModel = TabBarViewModel(
            isTabBarHiddenPublisher: NotificationCenter.default.getPublisher(for: DriveNotification.tabBar.name, publishing: Bool.self).eraseToAnyPublisher(),
            scrollToTopSubject: scrollToTopSubject,
            coordinator: coordinator,
            localSettings: tower.localSettings,
            volumeIdsController: tower.sharedVolumeIdsController,
            featureFlagsController: featureFlagsController,
            ratingBoosterFlowController: ratingBoosterFlowController,
            performanceMetricsController: tower.performanceMetricsController,
            deepLinkNotification: deepLink
        )
        let tabBarController = HidableTabBarController(viewModel: viewModel, children: childrenFactory.makeChildren())
        coordinator.tabBarController = tabBarController
        return tabBarController
    }

    private func makeChildrenFactory(deepLink: DeepLinkNotification?) -> TabBarChildrenFactoryProtocol {
        let visibilityPolicy = VisibilityPolicy(responders: [
            PhotosTabVisibilityResponder(localSettings: localSettings, repository: ProtonCoreFeatureFlags.FeatureFlagsRepository.shared),
            ComputersTabVisibilityResponder(featureFlags: featureFlagsController),
            SharedWithMeTabVisibilityResponder(featureFlags: featureFlagsController),
            SharedTabVisibilityResponder(featureFlags: featureFlagsController)
        ])
        return TabBarChildrenFactory(
            visibilityPolicy: visibilityPolicy,
            deepLink: deepLink,
            makeFilesViewControllerFactory: makeFilesViewControllerFactory,
            makePhotosViewController: makePhotosViewController,
            makeSharedViewController: makeSharedViewController,
            makeSharedWithMeViewController: makeSharedWithMeViewController,
            makeComputersViewController: makeComputersViewController
        )
    }

    private func makeFilesViewControllerFactory(deepLink: Deeplink?) -> UIViewController {
        let scrollToTopPublisher = scrollToTopSubject.eraseToAnyPublisher()
        let coordinator = FinderCoordinator(container: self, deeplink: deepLink, photoPickerCoordinator: pickersContainer.getPhotoCoordinator(), scrollToTopPublisher: scrollToTopPublisher)
        let myFilesRootFetcher = MyFilesRootFetcher(storage: tower.storage)
        let rootFolderView = RootFolderView(nodeID: myFilesRootFetcher.getRoot(), coordinator: coordinator).any()
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootFolderView })
        let vc = UIHostingController(rootView: rootView)
        coordinator.rootViewController = vc
        configureForTabBar(vc, tabBarItem: .files)
        return vc
    }

    private func makeDevicesRootViewControllerFactory(root: NodeIdentifier) -> UIViewController {
        let scrollToTopPublisher = scrollToTopSubject.eraseToAnyPublisher()
        let coordinator = FinderCoordinator(container: self, photoPickerCoordinator: pickersContainer.getPhotoCoordinator(), scrollToTopPublisher: scrollToTopPublisher)
        let rootFolderView = RootFolderView(nodeID: root, coordinator: coordinator).any()
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootFolderView })
        let vc = UIHostingController(rootView: rootView)
        coordinator.rootViewController = vc
        configureForTabBar(vc, tabBarItem: .computers)
        return vc
    }

    private func makePhotosViewController(deepLink: Deeplink?) -> UIViewController {
        let viewController = photosContainer.newPhotosContainer.makeRootViewController(configuration: .init())
        viewController.view.backgroundColor = ColorProvider.BackgroundNorm
        let nav = UINavigationController(rootViewController: viewController)
        configureForTabBar(nav, tabBarItem: .photos)
        return nav
    }

    private func makeSharedViewController(deepLink: Deeplink?) -> UIViewController {
        let scrollToTopPublisher = scrollToTopSubject.eraseToAnyPublisher()
        let coordinator = FinderCoordinator(container: self, photoPickerCoordinator: pickersContainer.getPhotoCoordinator(), scrollToTopPublisher: scrollToTopPublisher)
        let rootSharedView = RootSharedView(coordinator: coordinator)
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootSharedView })
        let vc = UIHostingController(rootView: rootView)
        coordinator.rootViewController = vc
        configureForTabBar(vc, tabBarItem: .shared)
        return vc
    }

    private func makeSharedWithMeViewController(deepLink: Deeplink?) -> UIViewController {
        let scrollToTopPublisher = scrollToTopSubject.eraseToAnyPublisher()
        let coordinator = FinderCoordinator(container: self, isSharedWithMe: true, photoPickerCoordinator: pickersContainer.getPhotoCoordinator(), scrollToTopPublisher: scrollToTopPublisher)
        let view = RootSharedWithMeView(coordinator: coordinator)
        let rootView = RootView(vm: RootViewModel(), activeArea: { view })
        let vc = UIHostingController(rootView: rootView)
        configureForTabBar(vc, tabBarItem: .sharedWithMe)
        coordinator.rootViewController = vc
        return vc
    }

    @MainActor
    private func makeComputersViewController(deepLink: Deeplink?) -> UIViewController {
        let coordinator = ComputersCoordinator(
            deviceRootViewControllerFactory: { [weak self] in
                guard let self else { return UIViewController() }
                return self.makeDevicesRootViewControllerFactory(root: $0.nodeIdentifier)
            },
            detailsScreenFactory: { [weak self] in
                guard let self else { return UIViewController() }
                return self.makeComputerDetail(computer: $0)
            },
            renameComputerFactory: { [weak self] in
                guard let self else { return UIViewController() }
                return self.makeRenameComputer(computer: $0, originalName: $1)
            },
            deleteComputerFactory: { [weak self] in
                guard let self else { return UIViewController() }
                return self.makeDeleteComputerAlertController(computer: $0, originalName: $1)
            }
        )

        let deviceRepository = CoreDataDeviceRepository(context: tower.storage.backgroundContext)
        let cellFactory = ComputersCellControllerFactory(repository: deviceRepository, errorHandler: UserMessageHandler(), coordinator: coordinator)
        let devicesRepository = DevicesRepository(storage: tower.storage)
        let observer = ComputersObserverInteractor(repository: devicesRepository)
        let scanner = ComputersScannerInteractor(remote: tower.client, cache: tower.storage)
        let loadStateRepository = ComputersLoadStateRepository(localSettings: tower.localSettings)
        let viewModel = ComputersViewModel(scanner: scanner, observer: observer, loadStateRepository: loadStateRepository, messageHandler: UserMessageHandler(), coordinator: coordinator, performanceMetricsController: tower.performanceMetricsController)
        let rootViewController = ComputersViewController(viewModel: viewModel, cellFactory: cellFactory)
        configureForTabBar(rootViewController, tabBarItem: .computers)
        let nc = MenuNavigationViewController(rootViewController: rootViewController)
        coordinator.navigationController = nc
        return nc
    }

    private func makeComputerDetail(computer: ComputerIdentifier) -> UIViewController {
        let repository: ComputerDetailsRepository = ComputerDetailsRepository(identifier: computer, storageManager: tower.storage)
        let detailSheetViewModel = ComputerDetailViewModel(repository: repository)
        let detailSheetView = DetailSheetView(viewModel: detailSheetViewModel)
        let hostingController = UIHostingController(rootView: detailSheetView)
        return hostingController
    }

    func makeRenameComputer(computer: ComputerIdentifier, originalName: String) -> UIViewController {
        let editedNode = NameEditingNode(computer: computer, name: originalName)
        let nodeRenamer = DeviceRenamer(
            storage: tower.storage,
            cloudNodeRenamer: tower.client.renameEntry,
            signersKitFactory: tower.sessionVault
        )
        let nameEditor = NodeNameEditor(
            storage: tower.storage,
            managedObjectContext: tower.storage.backgroundContext,
            nodeRenamer: nodeRenamer,
            nodeOperationPerformer: tower.getSdkNodeOperationPerformer()
        )
        let viewModel = EditNodeNameViewModel(node: editedNode, nameEditor: nameEditor, validator: NameValidations.userSelectedName)
        let formattingViewModel = FormattingFileViewModel(
            initialName: editedNode.fullName,
            nameAttributes: EditNodeViewController.nameAttributes,
            extensionAttributes: EditNodeViewController.nameAttributes
        )
        let viewController = EditNodeViewController()
        viewController.viewModel = viewModel
        viewController.tfViewModel = formattingViewModel

        let nc = ModalNavigationViewController(rootViewController: viewController)
        return nc
    }

    private func makeDeleteComputerAlertController(computer: ComputerIdentifier, originalName: String) -> UIViewController {
        let remover = ComputerRemover(client: tower.client, storage: tower.storage)
        let viewModel = DeleteComputerAlertViewModel(computer: computer, computerRemover: remover)
        let alert = UIAlertController(
            title: "",
            message: viewModel.removeComputerRemoveMessage,
            preferredStyle: .actionSheet
        )

        let deleteAction = UIAlertAction(title: viewModel.removeComputerRemoveButton, style: .destructive) { _ in
            viewModel.removeComputer()
        }

        let cancelAction = UIAlertAction(title: viewModel.removeComputerCancelButton, style: .cancel)

        alert.addAction(deleteAction)
        alert.addAction(cancelAction)

        return alert
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
        let container = makeSubscriptionsContainer()
        let viewController = container.makeRootViewController()
        return MenuNavigationViewController(rootViewController: viewController)
    }

    private func makeStorageBonusPromoViewController() -> UIViewController {
        let dependencies = StorageBonusPromoContainer.Dependencies(tower: tower)
        let container = StorageBonusPromoContainer(dependencies: dependencies)
        let rootViewController = container.makeRootViewController()
        return rootViewController
    }

    private func makeReportBugViewController() -> UIViewController {
        let factory = BugReportFactory(apiService: tower.networking, sessionVault: tower.sessionVault)
        return factory.makeBugReportViewController()
    }

    @MainActor
    private func makeSettingsViewController() -> UIViewController {
        return SettingsAssembler.assemble(
            apiService: networkService,
            tower: tower,
            keymaker: keymaker,
            photosContainer: photosContainer.settingsContainer,
            featureFlagsController: featureFlagsController
        )
    }

    @MainActor
    private func makeAccountSettingsSection() -> PMSettingsSectionViewModel {
        SettingsAssembler.makeAccountSettings(tower: tower, apiService: networkService)
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
