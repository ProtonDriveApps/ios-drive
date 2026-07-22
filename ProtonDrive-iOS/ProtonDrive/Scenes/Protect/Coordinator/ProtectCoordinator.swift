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

import UIKit
import Combine
import PDCore
import ProtonCoreHumanVerification
import SwiftUI
import PMSettings
import ProtonCoreKeymaker

protocol ProtectCoordinatorProtocol {
    func onLocked()
    func onUnlocked()
}

final class ProtectCoordinator: ProtectCoordinatorProtocol {
    private let humanVerificationHelper: HumanCheckHelper
    private let keymaker: Keymaker
    private var auxiliaryWindow: UIWindow?
    private var unlockedViewController: UIViewController?
    private var unlockedViewControllerFactory: () async -> UIViewController
    private var unlockTask: Task<Void, Never>?
    private(set) weak var viewController: ProtectViewController?

    init(
        viewController: ProtectViewController,
        humanVerificationHelper: HumanCheckHelper,
        keymaker: Keymaker,
        unlockedViewControllerFactory: @escaping () async -> UIViewController
    ) {
        self.viewController = viewController
        self.humanVerificationHelper = humanVerificationHelper
        self.keymaker = keymaker
        self.unlockedViewControllerFactory = unlockedViewControllerFactory
    }

    private var defaultWindow: UIWindow? {
        viewController?.view.window
    }

    func onLocked() {
        // The windowScene may be in `.background` or `.foregroundInactive` mode already.
        // We mainly need to avoid using `.unattached` one.
        guard let windowScene = UIApplication.shared.getAnyAttachedWindowScene() else {
            Log.error("Failed to get any attached window scene", error: nil, domain: .ui)
            return
        }
        let lockViewController = makeLockViewController()
        auxiliaryWindow = UIWindow(rootViewController: lockViewController, windowScene: windowScene)
    }

    func onUnlocked() {
        guard unlockTask == nil else {
            Log.debug("Ignore unlocked request since previous task is running", domain: .application)
            return
        }
        unlockTask = Task { @MainActor in
            guard let viewController else {
                Log.error("Trying to unlock while protect viewController is nil", error: nil, domain: .ui)
                return
            }
            if unlockedViewController == nil {
                let child = await unlockedViewControllerFactory()
                unlockedViewController = child
                viewController.add(child)
            } else {
                defaultWindow?.makeKeyAndVisible()
            }

            auxiliaryWindow = nil
            unlockTask = nil
        }
    }

    private func makeLockViewController() -> UIViewController {
        let logoutViewModel = LogoutAlertViewModel()
        let failedAttemptsCounter = SecureFailedAttemptsCounter(maximumNumberOfAttempts: Constants.maxNumberOfFailedUnlockAttempts)
        return PMUnlockViewControllerComposer
            .assemble(
                header: .drive(subtitle: nil),
                unlocker: self.keymaker,
                logoutManager: DriveLogoutManager(),
                failedAttemptsCounter: failedAttemptsCounter,
                logoutAlertSubtitle: logoutViewModel.message
            )
    }
}

extension UIWindow {
    convenience init?(rootViewController root: UIViewController, windowScene scene: UIWindowScene?) {
        guard let scene = scene else { return nil }
        self.init(windowScene: scene)
        rootViewController = root
        makeKeyAndVisible()
    }
}
