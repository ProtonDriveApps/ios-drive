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

import Combine
import Foundation
import PDCore
import PDCoreIOS
import ProtonCoreFeatureFlags
import ProtonCoreAuthentication
import ProtonCoreNetworking

protocol SignOutManager {
    func signOut(cacheCleanupStrategy: CacheCleanupStrategy) async
}

/// Sign out handler triggers by `DriveNotification.signOut` notification
final class DriveSignOutManager: SignOutManager {
    private let authenticator: Authenticator
    private let localSettings: LocalSettings
    private let sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    private let sessionVault: SessionVault
    private let storageManager: StorageManager

    private var featureFlags: DriveFeatureFlagsProvider? { tower?.featureFlags }
    private var tower: Tower?
    private var cancellables = Set<AnyCancellable>()

    init(
        authenticator: Authenticator,
        localSettings: LocalSettings,
        sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
        sessionVault: SessionVault,
        storageManager: StorageManager
    ) {
        self.authenticator = authenticator
        self.localSettings = localSettings
        self.sessionCommunicator = sessionCommunicator
        self.sessionVault = sessionVault
        self.storageManager = storageManager
        subscribeSignOut()
    }

    func appIsUnlocked(tower: Tower) {
        self.tower = tower
    }

    func signOut(cacheCleanupStrategy: CacheCleanupStrategy) async {
        let isAppUnlocked = tower != nil
        await AppShortcutManager().removeShortcutForLoggedOutUser()
        await signOut(cacheCleanupStrategy: cacheCleanupStrategy, isAppUnlocked: isAppUnlocked)
        tower = nil

        // notify cross-process observers
        DarwinNotificationCenter.shared.postNotification(.DidLogout)
    }

    @MainActor
    private func signOut(
        cacheCleanupStrategy: CacheCleanupStrategy,
        isAppUnlocked: Bool
    ) async {
        cleanUpFeatureFlags(isAppUnlocked: isAppUnlocked)
        
        if isAppUnlocked {
            await tower?.destroyCache(strategy: cacheCleanupStrategy)
            // No way to get sessionCredential before unlocking
            await removeSessionInBE(sessionVault: sessionVault, authenticator: authenticator)
        } else {
            await destroyCacheBeforeUnlocking(cacheCleanupStrategy: cacheCleanupStrategy)
        }
        sessionVault.signOut()
        sessionCommunicator.clearStateOnSignOut()
    }

    private func subscribeSignOut() {
        DriveNotification.signOut.publisher
            .sink { [weak self] _ in
                Task {
                    Log.info("DriveNotification.signOut", domain: .application)
                    NotificationCenter.default.post(.isLoggingOut)
                    await self?.signOut(cacheCleanupStrategy: .cleanEverything)
                    NotificationCenter.default.post(.checkAuthentication)
                }
            }
            .store(in: &cancellables)
    }
}

extension DriveSignOutManager {
    private func cleanUpFeatureFlags(isAppUnlocked: Bool) {
        if isAppUnlocked {
            if let userId = sessionVault.userInfo?.ID {
                ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.resetFlags(for: userId)
                ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.clearUserId()
            }
        } else {
            ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.resetFlags()
        }
        featureFlags?.stop()
    }

    private func removeSessionInBE(sessionVault: SessionVault, authenticator: Authenticator) async {
        Log.info("Attempting logout", domain: .networking)
        guard let coreCredential = sessionVault.sessionCredential else { return }
        let credential = Credential(coreCredential)

        await withCheckedContinuation { continuation in
            authenticator.closeSession(credential) { result in
                switch result {
                case .success:
                    Log.info("Logout successful", domain: .networking)
                    continuation.resume(returning: Void())
                case .failure(let error):
                    Log.error(error: error, domain: .networking)
                    continuation.resume(returning: Void())
                }
            }
        }
    }

    // This session never bootstrapped, tower and related objects don't be initialized
    // So clean up steps are less than Tower
    private func destroyCacheBeforeUnlocking(cacheCleanupStrategy: CacheCleanupStrategy) async {
        localSettings.cleanUp(cleanUserSpecificSettings: cacheCleanupStrategy.shouldCleanUserSpecificSettings)

        if cacheCleanupStrategy.shouldCleanMetadata {
            await storageManager.cleanUp()
        }
        // FileSystemSlot
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        try? FileManager.default.removeItem(at: documentsURL)

        PDFileManager.destroyCaches()
        PDFileManager.destroyPermanents()
        PDFileManager.destroyFPCaches()

        var keys: Set<String> = Set(UserDefaults.standard.dictionaryRepresentation().keys)
        if !cacheCleanupStrategy.shouldCleanBackupCache {
            let excludedKeys = SettingsStorageKey.keysExcludedFromWiping.map { $0.value }
            keys.subtract(excludedKeys)
        }
        keys.subtract(AppDefaultKey.keysExcludedFromWiping.map(\.value))
        keys.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        URLCache.shared.removeAllCachedResponses()
    }
}
