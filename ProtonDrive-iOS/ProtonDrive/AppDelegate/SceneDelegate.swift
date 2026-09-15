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
import SwiftUI
import PDCore
import PDCoreIOS
import PDLocalization
import PDUIComponents
import ProtonCoreKeymaker

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var container = DriveDependencyContainer()
    private let messageHandler = UserMessageHandler()
    private var debugOverlayController: DebugOverlayController?
    private var unlockCancellable: AnyCancellable?

    var window: UIWindow?
    private lazy var blurringView = UIVisualEffectView.blurred

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Log.info("scene willConnectTo session", domain: .application)
        if window != nil {
            Log.error("scene willConnectTo is called multiple times", domain: .application)
        }
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        container.launchApp(on: window)
        Localization.isUITest = Constants.isUITest
        WindowKey.defaultValue = window
        self.window = window

        // Delay showing overlay just a bit to avoid collision with showing the first screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            let factory = BugReportFactory(apiService: self.container.networkService, sessionVault: self.container.sessionVault)
            self.debugOverlayController = DebugOverlayController(localSettings: LocalSettings.shared, factory: factory)

            // When the app is force-quit (swiped up),
            // `openURLContexts` is not called automatically.
            if let urlContext = connectionOptions.urlContexts.first {
                self.scene(scene, openURLContexts: [urlContext])
            }

            handle(connectionOptions.shortcutItem)
        }
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
        Log.info("App version: \(Constants.clientVersion), \(DeviceInfo().info)", domain: .application)
        Log.info("Language diagnostics: \(Localization.languageDiagnosticsDescription())", domain: .application)
        NotificationCenter.default.post(.checkAuthentication)
        if (try? container.authenticatedContainer?.keymaker.mainKeyOrError) != nil {
            container.authenticatedContainer?.tower.forcePolling(volumeIDs: [])
        }
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
        if url.absoluteString == Constants.UniversalLink.singIn.rawValue { return }
        let fromShareExtension = url.absoluteString == Constants.UniversalLink.shareExtension.rawValue
        guard let authenticatedContainer = container.authenticatedContainer else {
            let message = fromShareExtension ? Localization.universalLink_incoming_auth_error : Localization.universalLink_protonFile_auth_error
            PDFileManager.cleanShareTempFolder()
            messageHandler.handleError(PlainMessageError(message))
            return
        }
        guard let rootViewController = window?.topMostViewController else {
            return
        }

        if fromShareExtension {
            handleShareExtensionEvent(container: authenticatedContainer)
        } else {
            let controller = authenticatedContainer.protonFileContainer.makeController(rootViewController: rootViewController)
            controller.openPreview(url)
        }
    }

    private func handleShareExtensionEvent(container: AuthenticatedDependencyContainer) {
        if isLocked() {
            Log.info("Get share extension event but app is locked", domain: .shareExtension)
            runAfterUnlocking { [weak self] in
                self?.presentIncomingFilesViewAfterUnlocking()
            }
        } else {
            presentIncomingFilesViewAfterUnlocking()
        }
    }

    @objc func presentIncomingFilesViewAfterUnlocking() {
        guard
            let rootViewController = self.window?.topMostViewController,
            let authenticatedContainer = self.container.authenticatedContainer
        else { return }
        if authenticatedContainer.featureFlagsController.hasRefactoredFinderView {
            IIncomingFilesCoordinator().present(on: rootViewController, with: authenticatedContainer)
        } else {
            IncomingFilesCoordinator().present(on: rootViewController, with: authenticatedContainer)
        }
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

// MARK: - Shortcut
extension SceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        handle(shortcutItem)
        completionHandler(true)
    }

    private func handle(_ shortcutItem: UIApplicationShortcutItem?) {
        guard let shortcutItem else { return }
        if shortcutItem.type == AppShortcut.scanDocument.identifier {
            handleScanDocumentShortcut()
        } else {
            Log.warning("Unknown shortcut \(shortcutItem.type)", domain: .application)
        }
    }

    private func handleScanDocumentShortcut() {
        if !isLoggedIn() { return }
        if isLocked() {
            Log.info("Get scan document action but app is locked", domain: .application)
            runAfterUnlocking { [weak self] in
                self?.presentScanDocumentAfterUnlocking()
            }
        } else {
            presentScanDocumentAfterUnlocking()
        }
    }

    private func presentScanDocumentAfterUnlocking() {
        let link = Deeplink()
        link.inject(.scanDocument)
        let notify = DeepLinkNotification(menuDestination: .myFiles, tab: .files, link: link)
        NotificationCenter.default.post(name: .deepLink, object: notify)
    }

    private func isLoggedIn() -> Bool {
        container.authenticatedContainer != nil
    }

    private func isLocked() -> Bool {
        let mainKey = try? container.keymaker.mainKeyOrError
        return mainKey == nil
    }

    private func runAfterUnlocking(block: @escaping () -> Void) {
        guard let container = container.authenticatedContainer else { return }
        let bootstrappedPublisher = container.bootstrapStateController.bootstrappedPublisher
        let sceneInitPubliser = container.sceneInitStateController.sceneIsInitPublisher
        unlockCancellable = NotificationCenter.default.publisher(for: Keymaker.Const.obtainedMainKey)
            .combineLatest(bootstrappedPublisher, sceneInitPubliser)
            .map { $1 && $2 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard isReady else { return }
                self?.unlockCancellable = nil
                block()
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
