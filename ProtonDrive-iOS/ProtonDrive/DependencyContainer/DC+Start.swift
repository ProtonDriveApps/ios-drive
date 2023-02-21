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

public extension DriveDependencyContainer {
    func makeStartViewController() -> UIViewController {
        let viewController = StartViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.isHidden = true
        navigationController.interactivePopGestureRecognizer?.isEnabled = false
        let viewModel = makeStartViewModel()
        let coordinator = makeStartCoordinator(viewController)

        viewController.viewModel = viewModel
        viewController.onAuthenticated = coordinator.onAuthenticated
        viewController.onNonAuthenticated = coordinator.onNonAuthenticated
        viewController.onFirstTimeAuthenticated = coordinator.onFirstTimeAuthenticated

        return navigationController
    }

    // MARK: - ViewModel
    private func makeStartViewModel() -> StartViewModel {
        let localSettings = LocalSettings(suite: appGroup)

        let authenticationPublisher = DriveNotification.checkAuthentication.publisher
            .map { _ in Void() }
            .setFailureType(to: Never.self)
            .eraseToAnyPublisher()
        
        let restartAppPublisher = NotificationCenter.default
            .publisher(for: .restartApplication)
            .map { _ in () }
            .eraseToAnyPublisher()
        
        return StartViewModel(
            isSignedIn: sessionVault.isSignedIn,
            localSettings: localSettings,
            restartAppPublisher: restartAppPublisher,
            checkAuthenticationPublisher: authenticationPublisher
        )
    }

    // MARK: - Coordinator
    private func makeStartCoordinator(_ viewController: StartViewController) -> StartCoordinator {
        let localSettings = LocalSettings(suite: appGroup)
        
        return StartCoordinator(
            viewController: viewController,
            authenticatedViewControllerFactory: makeProtectViewController,
            nonAuthenticatedViewControllerFactory: makeAuthenticateViewController,
            onboardingFactory: OnboardingFlowFactory(settings: localSettings).make
        )
    }
}
