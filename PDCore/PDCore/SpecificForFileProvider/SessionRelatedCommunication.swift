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

public protocol SessionRelatedCommunicatorBetweenMainAppAndExtensions {

    var isWaitingforNewChildSession: Bool { get }

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
    
    public static func forDDK(userDefaults: UserDefaults) -> UserDefaultsConfiguration {
        .init(userDefaults: userDefaults,
              sessionReadyPropertyKey: .ddkSessionReadyKey,
              sessionExpiredPropertyKey: .ddkSessionExpiredKey,
              sessionReadyKeyPath: \.ddkSessionReady,
              sessionExpiredKeyPath: \.ddkSessionExpired)
    }
}

public typealias SessionRelatedCommunicatorFactory = (
    SessionStore, Authenticator, @escaping (Credential, ChildSessionCredentialKind) -> Void
) -> SessionRelatedCommunicatorBetweenMainAppAndExtensions

public final class SessionRelatedCommunicatorForMainApp: SessionRelatedCommunicatorBetweenMainAppAndExtensions {
    
    #if os(iOS)
    let childClientID = "iOSDrive"
    let isChildSessionIndependent = false
    #elseif os(macOS)
    let childClientID = "macOSDrive"
    let isChildSessionIndependent = false
    #endif
    
    private let authenticator: Authenticator
    private let sessionStorage: SessionStore
    private let childSessionKind: ChildSessionCredentialKind
    private let userDefaultsConfiguration: UserDefaultsConfiguration
    private let userDefaultsObservationCenter: UserDefaultsObservationCenter
    public private(set) var isWaitingforNewChildSession = false

    private var userDefaults: UserDefaults { userDefaultsConfiguration.userDefaults }
    
    public init(userDefaultsConfiguration: UserDefaultsConfiguration,
                sessionStorage: SessionStore,
                childSessionKind: ChildSessionCredentialKind,
                authenticator: Authenticator) {
        self.userDefaultsConfiguration = userDefaultsConfiguration
        self.userDefaultsObservationCenter = UserDefaultsObservationCenter(userDefaults: userDefaultsConfiguration.userDefaults)
        self.authenticator = authenticator
        self.sessionStorage = sessionStorage
        self.childSessionKind = childSessionKind
    }
    
    public func startObservingSessionChanges() {
        userDefaultsObservationCenter.addObserver(self, of: userDefaultsConfiguration.sessionExpiredKeyPath) { [weak self] isExpired in
            guard let self, isExpired == true else { return }
            Task {
                await self.askMainAppToProvideNewChildSession()
            }
        }
    }
    
    public func stopObservingSessionChanges() {
        userDefaultsObservationCenter.removeObserver(self)
    }
    
    deinit {
        stopObservingSessionChanges()
    }
    
    // initial check on the app launch
    public func performInitialSetup() async {
        if userDefaults[keyPath: userDefaultsConfiguration.sessionExpiredKeyPath] == true {
            await askMainAppToProvideNewChildSession()
        }
    }
    
    public func askMainAppToProvideNewChildSession() async {
        guard let currentCredentials = sessionStorage.sessionCredential else { return }
        let parentSessionCredentials = Credential(currentCredentials)
        guard !parentSessionCredentials.isForUnauthenticatedSession else { return }
        do {
            try await fetchNewChildSession(parentSessionCredential: parentSessionCredentials)
            onChildSessionReady()
        } catch {
            Log.error("Fetching new child session failed", error: error, domain: .fileProvider)
        }
    }
    
    public func onChildSessionReady() {
        Log.info("Child session of kind \(childSessionKind) fetched and stored in the locker", domain: .sessionManagement)
        userDefaults.set(false, forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
        userDefaults.set(true, forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
    }
    
    public func fetchNewChildSession(parentSessionCredential: Credential) async throws {
        guard !isWaitingforNewChildSession else {
            Log.info("Not fetching new child session of kind \(childSessionKind) because fetching already in progress", domain: .sessionManagement)
            return
        }
        isWaitingforNewChildSession = true
        Log.info("Started fetching new child session of kind \(childSessionKind)", domain: .sessionManagement)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            authenticator.performForkingAndObtainChildSession(
                parentSessionCredential, useCase: .forChildClientID(childClientID, independent: isChildSessionIndependent, payload: nil)
            ) { [weak self] result in
                guard let self else { return }
                self.isWaitingforNewChildSession = false
                switch result {
                case .success(let newCredentials):
                    Log.info("Successfully fetched new child session of kind \(childSessionKind)", domain: .sessionManagement)
                    self.sessionStorage.storeNewChildSessionCredential(CoreCredential(newCredentials), kind: childSessionKind)
                    continuation.resume()
                case .failure(let error):
                    if Constants.buildType.isQaOrBelow {
                        Log.error(
                            "Failed to fetch new child session of kind \(childSessionKind) ",
                            error: error,
                            domain: .sessionManagement
                        )
                    } else {
                        Log.error(
                            "Failed to fetch new child session of kind \(childSessionKind) because of error",
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
    private let childSessionKind: ChildSessionCredentialKind
    private var userDefaults: UserDefaults { userDefaultsConfiguration.userDefaults }
    private let onChildSessionObtained: (Credential, ChildSessionCredentialKind) async -> Void
    public private(set) var isWaitingforNewChildSession = false

    public init(userDefaultsConfiguration: UserDefaultsConfiguration, 
                sessionStorage: SessionStore,
                childSessionKind: ChildSessionCredentialKind,
                onChildSessionObtained: @escaping (Credential, ChildSessionCredentialKind) async -> Void) {
        self.userDefaultsConfiguration = userDefaultsConfiguration
        self.userDefaultsObservationCenter = UserDefaultsObservationCenter(userDefaults: userDefaultsConfiguration.userDefaults)
        self.sessionStorage = sessionStorage
        self.childSessionKind = childSessionKind
        self.onChildSessionObtained = onChildSessionObtained
        startObservingSessionChanges()
    }
    
    deinit {
        stopObservingSessionChanges()
    }
    
    public func startObservingSessionChanges() {
        userDefaultsObservationCenter.addObserver(self, of: userDefaultsConfiguration.sessionReadyKeyPath) { [weak self] isReady in
            guard let self, isReady == true else { return }
            Task {
                await self.onChildSessionReady()
            }
        }
    }
    
    public func stopObservingSessionChanges() {
        userDefaultsObservationCenter.removeObserver(self)
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
        sessionStorage.consumeChildSessionCredentials(kind: childSessionKind)
        userDefaults.set(false, forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
        isWaitingforNewChildSession = false
        let credential: CoreCredential?
        switch childSessionKind {
        case .fileProviderExtension: credential = sessionStorage.sessionCredential
        case .ddk: credential = sessionStorage.ddkCredential
        }
        guard let credential else { return }
        let childSessionCredentials = Credential(credential)
        guard !childSessionCredentials.isForUnauthenticatedSession else { return }
        await onChildSessionObtained(childSessionCredentials, childSessionKind)
        Log.info("New child session of kind \(childSessionKind) consumed", domain: .sessionManagement)
    }
    
    public func askMainAppToProvideNewChildSession() async {
        guard !isWaitingforNewChildSession else { return }
        isWaitingforNewChildSession = true
        Log.info("Child session of kind \(childSessionKind) expired written to user defaults", domain: .sessionManagement)
        userDefaults.set(true, forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
    }
    
    public func clearStateOnSignOut() {
        Log.info("UserDefaults state cleaned on signout", domain: .sessionManagement)
        userDefaults.removeObject(forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
        userDefaults.removeObject(forKey: userDefaultsConfiguration.sessionReadyPropertyKey.rawValue)
    }
    
    public func fetchNewChildSession(parentSessionCredential: Credential) async throws {
        assertionFailure("This method should never be called.")
        throw AuthErrors.notImplementedYet("")
    }
    
    public func isChildSessionExpired() -> Bool {
        userDefaults.bool(forKey: userDefaultsConfiguration.sessionExpiredPropertyKey.rawValue)
    }
}
