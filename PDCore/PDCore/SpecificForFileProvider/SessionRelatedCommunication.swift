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

import Foundation
import ProtonCoreAuthentication
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCoreUtilities

public protocol SessionRelatedCommunicatorBetweenMainAppAndExtensions {
    
    var isWaitingforNewChildSessionAvailability: Atomic<Bool> { get }

    func onChildSessionReady() async
    func askMainAppToProvideNewChildSession() async
    func performInitialSetup() async
    func fetchNewChildSession(parentSessionCredential: Credential) async throws

    func startObservingSessionChanges()
    func stopObservingSessionChanges()
    func clearStateOnSignOut()
    func isChildSessionExpired() -> Bool
}

public struct UserDefaultsConfiguration {
    let userDefaults: UserDefaults
    let sessionReadyPropertyKey: UserDefaults.NotificationPropertyKeys
    let sessionExpiredPropertyKey: UserDefaults.NotificationPropertyKeys
    let sessionReadyKeyPath: KeyPath<UserDefaults, Bool>
    let sessionExpiredKeyPath: KeyPath<UserDefaults, Bool>
    
    public static func forFileProviderExtension(userDefaults: UserDefaults) -> UserDefaultsConfiguration {
        .init(userDefaults: userDefaults,
              sessionReadyPropertyKey: .childSessionReadyKey,
              sessionExpiredPropertyKey: .childSessionExpiredKey,
              sessionReadyKeyPath: \.childSessionReady,
              sessionExpiredKeyPath: \.childSessionExpired)
    }
}

public typealias SessionRelatedCommunicatorFactory = (
    SessionStore, Authenticator, @escaping (Credential) -> Void
) -> SessionRelatedCommunicatorBetweenMainAppAndExtensions

public final class SessionRelatedCommunicatorForMainApp: SessionRelatedCommunicatorBetweenMainAppAndExtensions {
    
    #if os(iOS)
    let childClientID = "iOSDrive"
    let isChildSessionIndependent = false
    #elseif os(macOS)
    let childClientID = "macOSDrive"
    let isChildSessionIndependent = false
    #endif
    
    private let authenticator: AuthenticatorInterface
    private let sessionStorage: SessionStore
    private let userDefaultsConfiguration: UserDefaultsConfiguration
    private let userDefaultsObservationCenter: UserDefaultsObservationCenter
    public private(set) var isWaitingforNewChildSessionAvailability: Atomic<Bool> = .init(false)
    public private(set) var isFetchingChildSession: Atomic<Bool> = .init(false)
    public private(set) var isObservingForSessionExpiration: Atomic<Bool> = .init(false)
    
    private var periodicCheckTask: Atomic<Task<Void, Error>?> = .init(nil)
    private let periodicCheckIntervalInMilliseconds: Int

    private var userDefaults: UserDefaults { userDefaultsConfiguration.userDefaults }
    
    public init(userDefaultsConfiguration: UserDefaultsConfiguration,
                customUserDefaultsObservationCenter: UserDefaultsObservationCenter? = nil,
                periodicCheckIntervalInMilliseconds: Int = 5000,
                sessionStorage: SessionStore,
                authenticator: AuthenticatorInterface) {
        self.userDefaultsConfiguration = userDefaultsConfiguration
        self.periodicCheckIntervalInMilliseconds = periodicCheckIntervalInMilliseconds
        self.userDefaultsObservationCenter = customUserDefaultsObservationCenter ?? UserDefaultsObservationCenter(userDefaults: userDefaultsConfiguration.userDefaults)
        self.authenticator = authenticator
        self.sessionStorage = sessionStorage
    }
    
    public func startObservingSessionChanges() {
        guard isObservingForSessionExpiration.changeValue(to: true) else { return }
        userDefaultsObservationCenter.addObserver(self, of: userDefaultsConfiguration.sessionExpiredKeyPath) { [weak self] isExpired in
            guard let self, isExpired == true else { return }
            Task {
                await self.askMainAppToProvideNewChildSession(onlyIfSessionIsExpired: true)
            }
        }
        tickTimer { [weak self] in
            guard let self else { return false }
            await askMainAppToProvideNewChildSession(onlyIfSessionIsExpired: true)
            return true
        }
    }
    
    func tickTimer(operation: @escaping () async -> Bool) {
        periodicCheckTask.mutate {
            guard isObservingForSessionExpiration.value else {
                if $0?.isCancelled == true { $0 = nil }
                return
            }
            let task = Task { [weak self] in
                // there is no need for handling the cancellation error. it will stop the operation, and this is all we care about
                try Task.checkCancellation()
                guard let periodicCheckIntervalInMilliseconds = self?.periodicCheckIntervalInMilliseconds else { return }
                try await Task.sleep(for: .milliseconds(periodicCheckIntervalInMilliseconds))
                guard self?.isObservingForSessionExpiration.value == true else { return }
                try Task.checkCancellation()
                guard await operation() else { return }
                try Task.checkCancellation()
                self?.tickTimer(operation: operation)
            }
            $0 = task
        }
    }
    
    public func stopObservingSessionChanges() {
        userDefaultsObservationCenter.removeObserver(self)
        periodicCheckTask.mutate {
            $0?.cancel()
            isObservingForSessionExpiration.mutate { $0 = false }
        }
    }
    
    deinit {
        stopObservingSessionChanges()
    }
    
    // initial check on the app launch
    public func performInitialSetup() async {
        if isChildSessionExpired() {
            await askMainAppToProvideNewChildSession()
        }
    }
    
    public func askMainAppToProvideNewChildSession() async {
        await askMainAppToProvideNewChildSession(onlyIfSessionIsExpired: false)
    }
    
    private func askMainAppToProvideNewChildSession(onlyIfSessionIsExpired: Bool) async {
        guard let currentCredentials = sessionStorage.sessionCredential else { return }
        let parentSessionCredentials = Credential(currentCredentials)
        guard !parentSessionCredentials.isForUnauthenticatedSession else { return }
        do {
            guard !onlyIfSessionIsExpired || isChildSessionExpired() else { return }
            let valueWasChangedFromFalseToTrue = isWaitingforNewChildSessionAvailability.changeValue(to: true)
            guard valueWasChangedFromFalseToTrue else {
                Log.info("Not fetching new child session because fetching already in progress", domain: .sessionManagement)
                return
            }
            _ = try await fetchNewChildSession(parentSessionCredential: parentSessionCredentials)
            onChildSessionReady()
            self.isWaitingforNewChildSessionAvailability.mutate { $0 = false }
        } catch {
            Log.error("Fetching new child session failed", error: error, domain: .fileProvider)
        }
    }
    
    public func onChildSessionReady() {
        Log.info("Child session fetched and stored in the locker", domain: .sessionManagement)
        userDefaults.set(false, forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
        userDefaults.set(true, forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
    }
    
    public func fetchNewChildSession(parentSessionCredential: Credential) async throws {
        let valueWasChangedFromFalseToTrue = isFetchingChildSession.changeValue(to: true)
        guard valueWasChangedFromFalseToTrue else {
            Log.info("Not fetching new child session because fetching already in progress", domain: .sessionManagement)
            return
        }
        Log.info("Started fetching new child session", domain: .sessionManagement)
        defer { isFetchingChildSession.mutate { $0 = false } }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            authenticator.performForkingAndObtainChildSession(
                parentSessionCredential, useCase: .forChildClientID(childClientID, independent: isChildSessionIndependent, payload: nil)
            ) { [weak self] result in
                guard let self else {
                    continuation.resume()
                    return
                }
                switch result {
                case .success(let newCredentials):
                    Log.info("Successfully fetched new child session", domain: .sessionManagement)
                    self.sessionStorage.storeNewChildSessionCredential(CoreCredential(newCredentials))
                    continuation.resume()
                case .failure(let error):
                    if Constants.buildType.isQaOrBelow {
                        Log.error(
                            "Failed to fetch new child session",
                            error: error,
                            domain: .sessionManagement
                        )
                    } else {
                        Log.error(
                            "Failed to fetch new child session because of error",
                            error: nil,
                            domain: .sessionManagement
                        )
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func clearStateOnSignOut() {
        Log.info("UserDefaults state cleaned on signout", domain: .sessionManagement)
        userDefaults.removeObject(forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
        userDefaults.removeObject(forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
    }
    
    public func isChildSessionExpired() -> Bool {
        userDefaults.bool(forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
    }
}

public final class SessionRelatedCommunicatorForExtension: SessionRelatedCommunicatorBetweenMainAppAndExtensions {
    
    private let sessionStorage: SessionStore
    private let userDefaultsConfiguration: UserDefaultsConfiguration
    private let userDefaultsObservationCenter: UserDefaultsObservationCenter
    private var userDefaults: UserDefaults { userDefaultsConfiguration.userDefaults }
    private let onChildSessionObtained: (Credential) async -> Void
    public private(set) var isWaitingforNewChildSessionAvailability: Atomic<Bool> = .init(false)
    public private(set) var isConsumingChildSession: Atomic<Bool> = .init(false)
    public private(set) var isObservingForSessionReadiness: Atomic<Bool> = .init(false)
    
    private var periodicCheckTask: Atomic<Task<Void, Error>?> = .init(nil)
    private let periodicCheckIntervalInMilliseconds: Int
    
    private let assertionProvider: AssertionProvider

    public init(userDefaultsConfiguration: UserDefaultsConfiguration,
                customUserDefaultsObservationCenter: UserDefaultsObservationCenter? = nil,
                periodicCheckIntervalInMilliseconds: Int = 5000,
                assertionProvider: AssertionProvider = SystemAssertionProvider.instance,
                sessionStorage: SessionStore,
                onChildSessionObtained: @escaping (Credential) async -> Void) {
        self.userDefaultsConfiguration = userDefaultsConfiguration
        self.periodicCheckIntervalInMilliseconds = periodicCheckIntervalInMilliseconds
        self.assertionProvider = assertionProvider
        self.userDefaultsObservationCenter = customUserDefaultsObservationCenter ?? UserDefaultsObservationCenter(userDefaults: userDefaultsConfiguration.userDefaults)
        self.sessionStorage = sessionStorage
        self.onChildSessionObtained = onChildSessionObtained
        startObservingSessionChanges()
    }
    
    deinit {
        stopObservingSessionChanges()
    }
    
    public func startObservingSessionChanges() {
        guard isObservingForSessionReadiness.changeValue(to: true) else { return }
        userDefaultsObservationCenter.addObserver(self, of: userDefaultsConfiguration.sessionReadyKeyPath) { [weak self] isReady in
            guard let self, isReady == true else { return }
            Task {
                await self.onChildSessionReady(onlyIfSessionIsReady: true)
            }
        }
        tickTimer { [weak self] in
            guard let self else { return false }
            await onChildSessionReady(onlyIfSessionIsReady: true)
            return true
        }
    }
    
    func tickTimer(operation: @escaping () async -> Bool) {
        periodicCheckTask.mutate {
            guard isObservingForSessionReadiness.value else {
                if $0?.isCancelled == true { $0 = nil }
                return
            }
            let task = Task { [weak self] in
                // there is no need for handling the cancellation error. it will stop the operation, and this is all we care about
                try Task.checkCancellation()
                guard let periodicCheckIntervalInMilliseconds = self?.periodicCheckIntervalInMilliseconds else { return }
                try await Task.sleep(for: .milliseconds(periodicCheckIntervalInMilliseconds))
                try Task.checkCancellation()
                guard self?.isObservingForSessionReadiness.value == true else { return }
                guard await operation() else { return }
                try Task.checkCancellation()
                self?.tickTimer(operation: operation)
            }
            $0 = task
        }
    }
    
    public func stopObservingSessionChanges() {
        userDefaultsObservationCenter.removeObserver(self)
        periodicCheckTask.mutate {
            $0?.cancel()
            isObservingForSessionReadiness.mutate { $0 = false }
        }
    }
    
    // initial check on the extension launch
    public func performInitialSetup() async {
        let isChildSessionReady = userDefaults
            .object(forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue) as? Bool
        // the nil case is for the first ever launch of the extension
        if isChildSessionReady == true || isChildSessionReady == nil {
            await onChildSessionReady()
        }
    }
    
    public func onChildSessionReady() async {
        await onChildSessionReady(onlyIfSessionIsReady: false)
    }
    
    private func onChildSessionReady(onlyIfSessionIsReady: Bool) async {
        guard !onlyIfSessionIsReady || userDefaults.bool(forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
        else { return }
        let valueWasChangedFromFalseToTrue = isConsumingChildSession.changeValue(to: true)
        guard valueWasChangedFromFalseToTrue else { return }
        sessionStorage.consumeChildSessionCredentials()
        defer { isConsumingChildSession.mutate { $0 = false } }
        defer { userDefaults.set(false, forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue) }
        defer { isWaitingforNewChildSessionAvailability.mutate { $0 = false } }
        guard let credential = sessionStorage.sessionCredential else { return }
        let childSessionCredentials = Credential(credential)
        guard !childSessionCredentials.isForUnauthenticatedSession else { return }
        await onChildSessionObtained(childSessionCredentials)
        Log.info("New child session consumed", domain: .sessionManagement)
    }
    
    public func askMainAppToProvideNewChildSession() async {
        let valueWasChangedFromFalseToTrue = isWaitingforNewChildSessionAvailability.changeValue(to: true)
        guard valueWasChangedFromFalseToTrue else { return }
        Log.info("Child session expired written to user defaults", domain: .sessionManagement)
        userDefaults.set(true, forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
    }
    
    public func clearStateOnSignOut() {
        Log.info("UserDefaults state cleaned on signout", domain: .sessionManagement)
        userDefaults.removeObject(forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
        userDefaults.removeObject(forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
    }
    
    public func fetchNewChildSession(parentSessionCredential: Credential) async throws {
        assertionProvider.assertionFailure("This method should never be called.")
        throw AuthErrors.notImplementedYet("")
    }
    
    public func isChildSessionExpired() -> Bool {
        userDefaults.bool(forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
    }
}
