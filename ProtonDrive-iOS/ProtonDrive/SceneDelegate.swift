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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var container = DriveDependencyContainer()

    var window: UIWindow?
    private lazy var blurringView = UIVisualEffectView.blurred

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        container.windowScene = windowScene

        let window = UIWindow(windowScene: windowScene)
        container.launchApp(on: window)
        self.window = window
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NotificationCenter.default.post(.checkAuthentication)
        obfuscateAppView(false)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        obfuscateAppView(true)

        if UIApplication.shared.isAppOnBackground {
            container.keymaker.updateAutolockCountdownStart()
        }
    }

    private func obfuscateAppView(_ show: Bool) {
        show ? window?.addSubview(blurringView) : blurringView.removeFromSuperview()
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
