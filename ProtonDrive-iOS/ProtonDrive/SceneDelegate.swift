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

import SwiftUI
import PDCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var container = DriveDependencyContainer()
    private let messageHandler = UserMessageHandler()

    var window: UIWindow?
    private lazy var blurringView = UIVisualEffectView.blurred

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Log.info("scene willConnectTo session", domain: .application)
        guard let windowScene = scene as? UIWindowScene else { return }
        container.windowScene = windowScene

        let window = UIWindow(windowScene: windowScene)
        container.launchApp(on: window)
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Log.info("sceneDidDisconnect", domain: .application)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Log.info("sceneDidBecomeActive", domain: .application)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        Log.info("sceneWillResignActive", domain: .application)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Log.info("sceneWillEnterForeground", domain: .application)
        NotificationCenter.default.post(.checkAuthentication)
        obfuscateAppView(false)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Log.info("sceneDidEnterBackground", domain: .application)
        obfuscateAppView(true)

        if UIApplication.shared.isAppOnBackground {
            container.keymaker.updateAutolockCountdownStart()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        Log.info("scene openURLContexts", domain: .application)

        guard let url = URLContexts.first?.url else {
            return
        }
        guard let authenticatedContainer = container.authenticatedContainer else {
            messageHandler.handleError(PlainMessageError("Please authenticate before opening the file."))
            return
        }
        guard let rootViewController = window?.topMostViewController else {
            return
        }

        let controller = authenticatedContainer.protonDocumentContainer.makeController(rootViewController: rootViewController)
        controller.openPreview(url)
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        Log.info("stateRestorationActivity for scene", domain: .application)
        return nil
    }

    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        Log.info("scene restoreInteractionStateWith stateRestorationActivity", domain: .application)
    }

    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        Log.info("scene willContinueUserActivityWithType userActivityType", domain: .application)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        Log.info("scene continue userActivity", domain: .application)
    }

    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        Log.info("scene didFailToContinueUserActivityWithType userActivityType", domain: .application)
    }

    func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
        Log.info("scene didUpdate userActivity", domain: .application)
    }

    private func obfuscateAppView(_ show: Bool) {
        if show {
            window?.addSubview(blurringView)
        } else {
            blurringView.removeFromSuperview()
        }
    }
}

extension UIVisualEffectView {
    static var blurred: UIVisualEffectView {
        let effectView = UIVisualEffectView(frame: UIScreen.main.bounds)
        effectView.effect = UIBlurEffect(style: .prominent)
        return effectView
    }
}

private extension UIApplication {
    /// The app has gone to the background if all of scenes are on the background
    var isAppOnBackground: Bool {
        applicationState == .background ||
        openSessions.compactMap(\.scene)
            .first(where: { $0.activationState != .background }) == nil
    }
}
