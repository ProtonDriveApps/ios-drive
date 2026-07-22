// Copyright (c) 2026 Proton AG
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

import Foundation
import UIKit
import ProtonCoreServices
import ProtonCoreHumanVerification
import ProtonCoreKeymaker

struct ProtectViewControllerFactory {
    private let lockedStateController: LockedStateControllerProtocol
    private let keymaker: Keymaker
    private let networkService: PMAPIService
    private var unlockedViewControllerFactory: (LockedStateControllerProtocol) async -> UIViewController

    init(
        lockedStateController: LockedStateControllerProtocol,
        keymaker: Keymaker,
        networkService: PMAPIService,
        unlockedViewControllerFactory: @escaping (LockedStateControllerProtocol) async -> UIViewController
    ) {
        self.lockedStateController = lockedStateController
        self.keymaker = keymaker
        self.networkService = networkService
        self.unlockedViewControllerFactory = unlockedViewControllerFactory
    }

    @MainActor
    func makeProtectViewController() -> ProtectViewController {
        let viewController = ProtectViewController()
        let coordinator = makeProtectCoordinator(controller: lockedStateController, viewController: viewController)
        let viewModel = ProtectViewModel(controller: lockedStateController, coordinator: coordinator)
        viewController.viewModel = viewModel
        return viewController
    }

    private func makeProtectCoordinator(
        controller: LockedStateControllerProtocol,
        viewController: ProtectViewController
    ) -> ProtectCoordinatorProtocol {
        let humanHelper = makeHumanVerificationHelper(networkService)
        return ProtectCoordinator(
            viewController: viewController,
            humanVerificationHelper: humanHelper,
            keymaker: keymaker,
            unlockedViewControllerFactory: {
                await self.unlockedViewControllerFactory(self.lockedStateController)
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
