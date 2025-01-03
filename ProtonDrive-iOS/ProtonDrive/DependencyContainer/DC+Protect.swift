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
import ProtonCoreKeymaker
import ProtonCoreServices
import ProtonCoreHumanVerification
import PDUploadVerifier

extension DriveDependencyContainer {
    @MainActor
    func makeProtectViewController() async -> UIViewController {
        let populatedController = PopulatedStateController()
        let tower = await initializeTowerInBackgroundQueue(populatedController: populatedController)

        let authenticatedContainer = AuthenticatedDependencyContainer(
            tower: tower, 
            keymaker: keymaker,
            networkService: networkService,
            localSettings: localSettings,
            windowScene: windowScene,
            settingsSuite: appGroup,
            authenticator: authenticator,
            populatedStateController: populatedController
        )
        
        self.authenticatedContainer = authenticatedContainer

        return await authenticatedContainer.makeProtectViewController()
    }

    func initializeTowerInBackgroundQueue(populatedController: PopulatedStateControllerProtocol) async -> Tower {
        let storageManager = StorageManager(suite: Constants.appGroup, sessionVault: sessionVault)
        let tower = Tower(
            storage: storageManager,
            eventStorage: EventStorageManager(suiteUrl: appGroup.directoryUrl),
            appGroup: appGroup,
            mainKeyProvider: keymaker,
            sessionVault: sessionVault,
            sessionCommunicator: sessionCommunicator,
            authenticator: authenticator,
            clientConfig: Constants.clientApiConfig,
            network: networkService,
            eventObservers: [],
            eventProcessingMode: .full,
            uploadVerifierFactory: ConcreteUploadVerifierFactory(),
            localSettings: localSettings,
            populatedStateController: populatedController
        )
        return tower
    }
}

extension AuthenticatedDependencyContainer {
    @MainActor
    func makeProtectViewController() async -> UIViewController {
        let viewController = ProtectViewController()
        let lockedStateController = makeLockedStateController()
        let coordinator = makeProtectCoordinator(controller: lockedStateController, viewController: viewController)
        let viewModel = makeProtectViewModel(controller: lockedStateController, coordinator: coordinator)
        viewController.viewModel = viewModel
        return viewController
    }

    private func makeProtectViewModel(controller: LockedStateControllerProtocol, coordinator: ProtectCoordinatorProtocol) -> ProtectViewModel {
        return ProtectViewModel(
            controller: controller,
            lockManager: tower,
            signoutManager: tower,
            coordinator: coordinator
        )
    }

    private func makeLockedStateController() -> LockedStateControllerProtocol {
        let removedMainKeyPublisher = NotificationCenter.default.publisher(for: Keymaker.Const.removedMainKeyFromMemory)
            .merge(with: NotificationCenter.default.publisher(for: Keymaker.Const.requestMainKey))
            .filter { _ in self.keymaker.isProtected() == true }
            .map { _ in Void() }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()

        let obtainedMainKeyPublisher = NotificationCenter.default.publisher(for: Keymaker.Const.obtainedMainKey)
            .map { _ in Void() }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        return LockedStateController(
            isLocked: keymaker.isLocked,
            removedMainKeyPublisher: removedMainKeyPublisher,
            obtainedMainKeyPublisher: obtainedMainKeyPublisher
        )
    }

    private func makeProtectCoordinator(controller: LockedStateControllerProtocol, viewController: ProtectViewController) -> ProtectCoordinatorProtocol {
        let humanHelper = makeHumanVerificationHelper(networkService)
        humanCheckHelper = humanHelper
        return ProtectCoordinator(
            windowScene: windowScene,
            viewController: viewController,
            humanVerificationHelper: humanHelper,
            lockedViewControllerFactory: makeLockViewController,
            unlockedViewControllerFactory: { [unowned self] in
                self.makePopulateViewController(lockedStateController: controller)
            }
        )
    }

    private func makeHumanVerificationHelper(_ networkService: PMAPIService) -> HumanCheckHelper {
        let helper = HumanCheckHelper(
            apiService: networkService,
            supportURL: URL(string: "https://protonmail.com/support/knowledge-base/human-verification/")!,
            inAppTheme: { .matchSystem },
            clientApp: .drive
        )
        // We're replacing the delegate set in the creation of InitialServices, so the HV delegate in iOS will be HumanCheckHelper instead of PMAPIClient, which still will be the HV delegate in macOS
        networkService.humanDelegate = helper
        return helper
    }
}
