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
    init(userDefaults: UserDefaults, sessionStorage: SessionStore, authenticator: Authenticator, apiService: PMAPIService)
    func onChildSessionReady()
    func askMainAppToProvideNewChildSession()
    func performInitialSetup()
    func startObservingSessionChanges()
    func stopObservingSessionChanges()
    func clearStateOnSignOut()
    func fetchNewChildSession(parentSessionCredential: Credential,
                              completionBlock: @escaping (Result<Void, Error>) -> Void)
    func isChildSessionExpired() -> Bool
}

public typealias SessionRelatedCommunicatorFactory = (
    UserDefaults, SessionStore, Authenticator, PMAPIService
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
    private let userDefaults: UserDefaults
    private let userDefaultsObservationCenter: UserDefaultsObservationCenter
    private var isFetchingNewChildSession = false
    
    public init(userDefaults: UserDefaults, sessionStorage: SessionStore, authenticator: Authenticator, apiService _: PMAPIService) {
        self.userDefaults = userDefaults
        self.userDefaultsObservationCenter = UserDefaultsObservationCenter(userDefaults: userDefaults)
        self.authenticator = authenticator
        self.sessionStorage = sessionStorage
    }
    
    public func startObservingSessionChanges() {
        userDefaultsObservationCenter.addObserver(self, of: \.childSessionExpired) { [weak self] isExpired in
            guard let self, isExpired == true else { return }
            self.askMainAppToProvideNewChildSession()
        }
    }
    
    public func stopObservingSessionChanges() {
        userDefaultsObservationCenter.removeObserver(self)
    }
    
    deinit {
        stopObservingSessionChanges()
    }
    
    // initial check on the app launch
    public func performInitialSetup() {
        if userDefaults.childSessionExpired == true {
            askMainAppToProvideNewChildSession()
        }
    }
    
    public func askMainAppToProvideNewChildSession() {
        guard let currentCredentials = sessionStorage.sessionCredential else { return }
        let parentSessionCredentials = Credential(currentCredentials)
        guard !parentSessionCredentials.isForUnauthenticatedSession else { return }
        fetchNewChildSession(parentSessionCredential: parentSessionCredentials) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.onChildSessionReady()
            case .failure:
                // TODO: how to handle error? Should we retry? Maybe after some time?
                break
            }
        }
    }
    
    public func onChildSessionReady() {
        Log.info("Child session fetched and stored in the locker", domain: .sessionManagement)
        userDefaults.set(false, forKey: UserDefaults.NotificationPropertyKeys.childSessionExpiredKey.rawValue)
        userDefaults.set(true, forKey: UserDefaults.NotificationPropertyKeys.childSessionReadyKey.rawValue)
    }
    
    public func fetchNewChildSession(parentSessionCredential: Credential,
                                     completionBlock: @escaping (Result<Void, Error>) -> Void) {
        guard !isFetchingNewChildSession else {
            Log.info("Not fetching new child session because fetching already in progress", domain: .sessionManagement)
            return
        }
        isFetchingNewChildSession = true
        Log.info("Started fetching new child session", domain: .sessionManagement)
        authenticator.performForkingAndObtainChildSession(
            parentSessionCredential, useCase: .forChildClientID(childClientID, independent: isChildSessionIndependent)
        ) { [weak self] result in
            guard let self else { return }
            self.isFetchingNewChildSession = false
            switch result {
            case .success(let newCredentials):
                Log.info("Successfully fetched new child session", domain: .sessionManagement)
                self.sessionStorage.storeNewChildSessionCredential(CoreCredential(newCredentials))
                completionBlock(.success)
            case .failure(let error):
                #if HAS_QA_FEATURES
                Log.error("Failed to fetch new child session with error \(error.localizedDescription)",
                          domain: .sessionManagement)
                #else
                Log.error("Failed to fetch new child session becuse of error",
                          domain: .sessionManagement)
                #endif
                completionBlock(.failure(error))
            }
        }
    }
    
    public func clearStateOnSignOut() {
        Log.info("UserDefaults state cleaned on signout", domain: .sessionManagement)
        userDefaults.removeObject(forKey: UserDefaults.NotificationPropertyKeys.childSessionExpiredKey.rawValue)
        userDefaults.removeObject(forKey: UserDefaults.NotificationPropertyKeys.childSessionReadyKey.rawValue)
    }
    
    public func isChildSessionExpired() -> Bool {
        userDefaults.bool(forKey: UserDefaults.NotificationPropertyKeys.childSessionExpiredKey.rawValue)
    }
}

public final class SessionRelatedCommunicatorForExtension: SessionRelatedCommunicatorBetweenMainAppAndExtensions {
    
    private let apiService: PMAPIService
    private let sessionStorage: SessionStore
    private let userDefaults: UserDefaults
    private let userDefaultsObservationCenter: UserDefaultsObservationCenter
    
    public init(userDefaults: UserDefaults, sessionStorage: SessionStore, authenticator _: Authenticator, apiService: PMAPIService) {
        self.userDefaults = userDefaults
        self.userDefaultsObservationCenter = UserDefaultsObservationCenter(userDefaults: userDefaults)
        self.sessionStorage = sessionStorage
        self.apiService = apiService
        startObservingSessionChanges()
    }
    
    deinit {
        stopObservingSessionChanges()
    }
    
    public func startObservingSessionChanges() {
        userDefaultsObservationCenter.addObserver(self, of: \.childSessionReady) { [weak self] isReady in
            guard let self, isReady == true else { return }
            self.onChildSessionReady()
        }
    }
    
    public func stopObservingSessionChanges() {
        userDefaultsObservationCenter.removeObserver(self)
    }
    
    // initial check on the extension launch
    public func performInitialSetup() {
        let isChildSessionReady = userDefaults
            .object(forKey: UserDefaults.NotificationPropertyKeys.childSessionReadyKey.rawValue) as? Bool
        // the nil case is for the first ever launch of the extension
        if isChildSessionReady == true || isChildSessionReady == nil {
            onChildSessionReady()
        }
    }
    
    public func onChildSessionReady() {
        sessionStorage.consumeChildSessionCredentials()
        userDefaults.set(false, forKey: UserDefaults.NotificationPropertyKeys.childSessionReadyKey.rawValue)
        guard let currentCredentials = sessionStorage.sessionCredential else {
            return
        }
        let childSessionCredentials = Credential(currentCredentials)
        guard !childSessionCredentials.isForUnauthenticatedSession else {
            return
        }
        apiService.setSessionUID(uid: childSessionCredentials.UID)
        Log.info("New child session consumeds", domain: .sessionManagement)
    }
    
    public func askMainAppToProvideNewChildSession() {
        Log.info("Child session expired written to user defaults", domain: .sessionManagement)
        userDefaults.set(true, forKey: UserDefaults.NotificationPropertyKeys.childSessionExpiredKey.rawValue)
    }
    
    public func clearStateOnSignOut() {
        Log.info("UserDefaults state cleaned on signout", domain: .sessionManagement)
        userDefaults.removeObject(forKey: UserDefaults.NotificationPropertyKeys.childSessionExpiredKey.rawValue)
        userDefaults.removeObject(forKey: UserDefaults.NotificationPropertyKeys.childSessionReadyKey.rawValue)
    }
    
    public func fetchNewChildSession(parentSessionCredential: Credential,
                                     completionBlock: @escaping (Result<Void, Error>) -> Void) {
        assertionFailure("This method should never be called.")
        completionBlock(.failure(AuthErrors.notImplementedYet("")))
    }
    
    public func isChildSessionExpired() -> Bool {
        userDefaults.bool(forKey: UserDefaults.NotificationPropertyKeys.childSessionExpiredKey.rawValue)
    }
}
