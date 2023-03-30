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
import PDCore
import PDUIComponents
import ProtonCore_FeatureSwitch
import ProtonCore_Services
import BackgroundTasks

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    @SettingsStorage("firstLaunchHappened") private var firstLaunchHappened: Bool?

    private var orientationLock = UIInterfaceOrientationMask.allButUpsideDown

    override init() {
        self._firstLaunchHappened.configure(with: Constants.appGroup)
        PDFileManager.configure(with: Constants.appGroup)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        lockOrientationIfNeeded(in: .portrait)
        UINavigationBar.setupFlatNavigationBarSystemWide()
        UNUserNotificationCenter.current().delegate = self

        configureFeatureSwitches()

        // swiftlint:disable no_print
        #if DEBUG
        print("💠 Bundle: " + Bundle(for: type(of: self)).bundlePath)
        #endif
        // swiftlint:enable no_print

        #if DEBUG
        setupUITestsMocks()
        #endif

        #if SUPPORTS_BACKGROUND_UPLOADS
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.backgroundTaskIdentifier,
            using: nil
        ) {
            ConsoleLogger.shared?.logAndNotify(title: "👶", message: "Start processing background task", osLogType: Constants.self)
            NotificationCenter.default.post(name: .scheduleUploads, object: $0)
        }
        #endif

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
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        #if DEBUG
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Memory warning"
        content.subtitle = "App will be killed"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Environment(\.storage).wrappedValue.prepareForTermination()
    }

    private func configureFeatureSwitches() {
        // These need to be set as early as possible in the app lifecycle

        // Core Feature Flags
        FeatureFactory.shared.enable(&.unauthSession)

        #if DEBUG
        FeatureFactory.shared.enable(&.enforceUnauthSessionStrictVerificationOnBackend)
        #endif
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
