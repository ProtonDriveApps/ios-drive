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

import PDClient
import PDCore
import UIKit
import Combine
import ProtonCoreFeatureFlags
import ProtonCoreAccountRecovery
import ProtonCorePushNotifications
import ProtonCoreServices

public extension DriveDependencyContainer {
    func launchApp(on window: UIWindow) {
        let viewController = LaunchViewController()
        let viewModel = makeLaunchViewModel()
        let coordinator = makeLaunchCoordinator(window, viewController)

        viewController.viewModel = viewModel
        viewController.onViewDidLoad = coordinator.launchApp
        viewController.onPresentAlert = coordinator.presentAlert
        viewController.onPresentAccountRecovery = coordinator.presentAccountRecovery

        window.makeKeyAndVisible()
    }

    // MARK: - ViewModel
    private func makeLaunchViewModel() -> LaunchViewModel {
        let configurator = makeLaunchConfigurator()

        let alertDismissing = DriveNotification.didDismissAlert
            .publisher
            .map { _ in Void() }
            .eraseToAnyPublisher()

        let bannerPublisher = NotificationCenter.default.publisher(for: .banner, object: nil)
            .compactMap { notification -> BannerModel? in
            guard let bannerModel = notification.object as? BannerModel else { return nil }
            return bannerModel
            }
            .setFailureType(to: Never.self)
            .eraseToAnyPublisher()
        
        let userPublisher = sessionVault
            .objectWillChange
            .compactMap { [weak self] _ in self?.sessionVault.getUserInfo() }
            .replaceNil(with: .blank)
            .removeDuplicates()
            .eraseToAnyPublisher()

        let accountRecoveryWrapper = AccountRecoveryWrapper(publisher: PassthroughSubject<Void, Never>(), 
                                                            apiService: networkService)

        if featureFlagRepository.isEnabled(CoreFeatureFlagType.accountRecovery) {
            let driveHandler = AccountRecoveryHandler()
            driveHandler.handler = { _ in
                accountRecoveryWrapper.publisher.send()
                return .success
            }
            NotificationType.allAccountRecoveryTypes.forEach {
                pushNotificationService?.registerHandler(driveHandler, forType: $0)
            }
        }

        return LaunchViewModel(
            alertPresenting: networkClient.failureAlertPublisher,
            alertDismissing: alertDismissing,
            userPublisher: userPublisher,
            bannerPublisher: bannerPublisher,
            accountRecoveryWrapper: accountRecoveryWrapper,
            configurator: configurator
        )
    }

    private func makeLaunchConfigurator() -> LaunchConfigurator {
        let sentry = SentryLaunchConfigurator(sentryClient: SentryClient.shared, localSettings: localSettings) { [weak self] in self?.client }
        let keyChain = KeychainLaunchConfigurator(suite: Constants.appGroup)

        return iOSDriveLaunchConfigurator([sentry, keyChain])
    }

    // MARK: - Coordinator
    private func makeLaunchCoordinator(
        _ window: UIWindow,
        _ viewController: LaunchViewController
    ) -> LaunchCoordinator {
        LaunchCoordinator(
            window: window,
            viewController: viewController,
            startViewControllerFactory: makeStartViewController,
            failingAlertFactory: makeAlert
        )
    }

    private func makeAlert(from alert: FailingAlert) -> UIAlertController {
        let alertController = UIAlertController(
            title: alert.title,
            message: alert.message,
            preferredStyle: .alert
        )

        if let primary = alert.primaryAction {
            let action = UIAlertAction(title: primary.title, style: .destructive) { _ in
                primary.action()
                NotificationCenter.default.post(.didDismissAlert)
            }
            alertController.addAction(action)
        }

        if let secondary = alert.secondaryAction {
            let action = UIAlertAction(title: secondary.title, style: .cancel) { _ in
                secondary.action()
                NotificationCenter.default.post(.didDismissAlert)
            }
            alertController.addAction(action)

        } else {
            let action = UIAlertAction(title: "OK", style: .cancel) { _ in
                NotificationCenter.default.post(.didDismissAlert)
            }
            alertController.addAction(action)
        }

        return alertController
    }
}

public struct AccountRecoveryWrapper {
    public let publisher: PassthroughSubject<Void, Never>
    public let apiService: ProtonCoreServices.APIService
}
