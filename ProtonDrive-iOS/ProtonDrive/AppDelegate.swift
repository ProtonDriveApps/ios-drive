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
import UIKit
import UserNotifications
import PDClient
import PDCore
import PDUIComponents
import ProtonCoreServices
import ProtonCoreCryptoGoInterface
import ProtonCoreCryptoPatchedGoImplementation
import ProtonCoreFeatureFlags
import ProtonCorePushNotifications
import PDLoadTesting

#if LOAD_TESTING && SSL_PINNING
#error("Load testing requires turning off SSL pinning, so it cannot be set for SSL-pinning targets")
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, hasPushNotificationService {
    @SettingsStorage("firstLaunchHappened") private var firstLaunchHappened: Bool?
    private var logConfigurator: LogsConfigurator?

    private var orientationLock = UIInterfaceOrientationMask.allButUpsideDown
    public var pushNotificationService: PushNotificationServiceProtocol?

    override init() {
        self._firstLaunchHappened.configure(with: Constants.appGroup)
        PDFileManager.configure(with: Constants.appGroup)
        super.init()
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // the feature flags are not available at this point. The Log.setup call will be repeated in the SceneDelegate because of that
        self.logConfigurator = LogsConfigurator(logSystem: .iOSApp, featureFlags: LocalSettings.shared)
        Log.info("application willFinishLaunchingWithOptions", domain: .application)
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Log.info("application didFinishLaunchingWithOptions", domain: .application)

        lockOrientationIfNeeded(in: .portrait)
        inject(cryptoImplementation: ProtonCoreCryptoPatchedGoImplementation.CryptoGoMethodsImplementation.instance)
        // Inject build type to enable build differentiation. (Build macros don't work in SPM)
        PDCore.Constants.buildType = Constants.buildType
        #if LOAD_TESTING && !SSL_PINNING
        LoadTesting.enableLoadTesting()
        #endif

        UINavigationBar.setupFlatNavigationBarSystemWide()
        UIToolbar.setupApparance()
        UNUserNotificationCenter.current().delegate = self

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitests") {
            UIView.setAnimationsEnabled(false)
        }
        setupUITestsMocks()
        #endif
        BackgroundModesRegistry.register()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        Log.info("application didDiscardSceneSessions sceneSessions", domain: .application)
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        #if HAS_BETA_FEATURES
        // We only want to send errors to sentry from beta builds to see the occurrence of the issue.
        Log.error("application applicationDidReceiveMemoryWarning ⚠️", domain: .application)
        #else
        Log.warning("application applicationDidReceiveMemoryWarning ⚠️", domain: .application)
        #endif
        #if DEBUG
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Memory warning"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Log.info("applicationDidBecomeActive", domain: .application)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        Log.info("applicationWillResignActive", domain: .application)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Log.info("applicationWillTerminate 🔴", domain: .application)
        Environment(\.storage).wrappedValue.prepareForTermination()
    }
}

/// Locking screen orientation for the iPhone
extension AppDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return orientationLock
        } else {
            return [.allButUpsideDown]
        }
    }

    func lockOrientationIfNeeded(in orientation: UIInterfaceOrientationMask) {
        if UIDevice.current.userInterfaceIdiom == .phone {
            orientationLock = orientation
        }
    }

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.info(#function, domain: .application)
        pushNotificationService?.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.info(#function, domain: .application)
        pushNotificationService?.didFailToRegisterForRemoteNotifications(withError: error)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        #if DEBUG
        completionHandler([.alert])
        #else
        completionHandler([])
        #endif
    }
}
