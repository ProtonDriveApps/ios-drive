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
import Combine
import PDCore
import ProtonCore_HumanVerification
import SwiftUI

final class ProtectCoordinator {
    private(set) unowned var viewController: ProtectViewController

    private var unlockedViewController: UIViewController?

    private var lockedViewControllerFactory: () -> UIViewController
    private var unlockedViewControllerFactory: () -> UIViewController

    private let humanVerificationHelper: HumanCheckHelper
    private var auxiliaryWindow: UIWindow?
    private var scene: UIWindowScene

    public init(
        windowScene: UIWindowScene,
        viewController: ProtectViewController,
        humanVerificationHelper: HumanCheckHelper,
        lockedViewControllerFactory: @escaping () -> UIViewController,
        unlockedViewControllerFactory: @escaping () -> UIViewController
    ) {
        self.scene = windowScene
        self.viewController = viewController
        self.humanVerificationHelper = humanVerificationHelper
        self.lockedViewControllerFactory = lockedViewControllerFactory
        self.unlockedViewControllerFactory = unlockedViewControllerFactory
    }

    private var defaultWindow: UIWindow? {
        viewController.view.window
    }

    func onLocked() {
        let lockViewController = lockedViewControllerFactory()
        auxiliaryWindow = UIWindow(rootViewController: lockViewController, windowScene: scene)
    }

    func onUnlocked() {
        if unlockedViewController == nil {
            let child = unlockedViewControllerFactory()
            unlockedViewController = child
            viewController.add(child)
        } else {
            defaultWindow?.makeKeyAndVisible()
        }

        auxiliaryWindow = nil
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
