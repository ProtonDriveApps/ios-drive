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
import UIKit
import PDClient
import PDCore
import PDCoreIOS
import ProtonCoreKeymaker
import ProtonCoreAuthentication
import ProtonCoreHumanVerification
import ProtonCoreFeatureFlags
import ProtonCorePushNotifications
import ProtonCoreServices

public class DriveDependencyContainer {
    private let initialServices: InitialServices
    private let driveKeymaker: Keymaker

    var appGroup: SettingsStorageSuite { Constants.appGroup }
    var authenticatedContainer: AuthenticatedDependencyContainer?
    let hvHelper: HumanCheckHelper
    private(set) var autoLocker: Autolocker?
    let lockedStateController: LockedStateController
    let storageManager: StorageManager
    let signOutManager: DriveSignOutManager

    public init() {
        let autolocker = Autolocker(lockTimeProvider: DriveKeychain.shared)
        self.autoLocker = autolocker
        let keymaker = DriveKeymaker(autolocker: autolocker, keychain: DriveKeychain.shared)

        self.driveKeymaker = keymaker

        func makeInitialServices() -> InitialServices {
            let config = Constants.clientApiConfig
            return InitialServices(
                userDefault: Constants.appGroup.userDefaults,
                clientConfig: config,
                mainKeyProvider: keymaker,
                autoLocker: autolocker,
                sessionRelatedCommunicatorFactory: { sessionStore, authenticator, _ in
                    SessionRelatedCommunicatorForMainApp(
                        userDefaultsConfiguration: .forFileProviderExtension(userDefaults: Constants.appGroup.userDefaults),
                        sessionStorage: sessionStore,
                        authenticator: authenticator
                    )
                }
            )
        }
        initialServices = makeInitialServices()

        storageManager = StorageManager(suite: Constants.appGroup)
        lockedStateController = LockedStateControllerFactory().make(keymaker: keymaker, storageManager: storageManager)
        signOutManager = DriveSignOutManager(
            authenticator: initialServices.authenticator,
            localSettings: initialServices.localSettings,
            sessionCommunicator: initialServices.sessionRelatedCommunicator,
            sessionVault: initialServices.sessionVault,
            storageManager: storageManager
        )

        hvHelper = HumanCheckHelper(
            apiService: initialServices.networkService,
            supportURL: URL(string: "https://protonmail.com/support/knowledge-base/human-verification/")!,
            inAppTheme: { .matchSystem },
            clientApp: .drive
        )
        // We're replacing the delegate set in the creation of InitialServices, so the HV delegate in iOS will be HumanCheckHelper instead of PMAPIClient, which still will be the HV delegate in macOS
        initialServices.networkService.humanDelegate = hvHelper
        setPushNotificationService()
    }

    func discardAuthenticatedContainer() {
        authenticatedContainer = nil
        initialServices.networkService.humanDelegate = hvHelper
    }

    var sessionVault: SessionVault {
        initialServices.sessionVault
    }
    
    var networkClient: PMAPIClient {
        initialServices.networkClient
    }

    var keymaker: Keymaker {
        driveKeymaker
    }

    var authenticator: Authenticator {
        initialServices.authenticator
    }

    var networkService: PMAPIService {
        initialServices.networkService
    }
    
    var sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions {
        initialServices.sessionRelatedCommunicator
    }

    var client: Client? {
        authenticatedContainer?.tower.client
    }

    var pushNotificationService: PushNotificationServiceProtocol? {
        initialServices.pushNotificationService
    }

    var featureFlagsRepository: FeatureFlagsRepositoryProtocol {
        initialServices.featureFlagsRepository
    }

    var localSettings: LocalSettings {
        initialServices.localSettings
    }

    var connectionStateResource: ConnectionStateResource {
        initialServices.connectionStateResource
    }

    private func setPushNotificationService() {
        guard
            !Constants.isUITest,
            !PDCore.Constants.runningInExtension,
            let pushNotificationService = initialServices.pushNotificationService,
            var delegate = UIApplication.shared.delegate as? hasPushNotificationService
        else { return }
        delegate.pushNotificationService = pushNotificationService
    }
}
