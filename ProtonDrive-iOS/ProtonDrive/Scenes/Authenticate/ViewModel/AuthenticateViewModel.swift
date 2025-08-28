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

import PDCore
import ProtonCoreLogin
import ProtonCoreNetworking
import PDLocalization

public final class AuthenticateViewModel {

    private let sessionStore: SessionStore
    private let sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    private let coordinator: AuthenticateCoordinator
    private let localSettings: LocalSettings
    private var hasAuthenticatonCompleted = false

    init(sessionStore: SessionStore,
         sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
         coordinator: AuthenticateCoordinator,
         localSettings: LocalSettings) {
        self.sessionStore = sessionStore
        self.sessionCommunicator = sessionCommunicator
        self.coordinator = coordinator
        self.localSettings = localSettings
    }

    var welcomeBody: String {
        Localization.authentication_welcome_text
    }

    func save(_ userData: UserData, _ errorBlock: @escaping (Error) -> Void) {
        #if DEBUG
            dump("Credential 🔑: \n \(userData.credential)")
        #endif

        let parentSessionCredential = Credential(userData.credential, scopes: userData.scopes)
        Task { @MainActor in
            do {
                try await sessionCommunicator.fetchNewChildSession(parentSessionCredential: parentSessionCredential)
                sessionStore.storeCredential(CoreCredential(parentSessionCredential))
                sessionStore.storeUser(userData.user)
                sessionStore.storeAddresses(userData.addresses)
                sessionStore.storePassphrases(userData.passphrases)
                completeAuthentication()

                localSettings.userId = parentSessionCredential.userID
                await sessionCommunicator.onChildSessionReady()
            } catch {
                errorBlock(error)
            }
        }
    }
    
    func completeAuthentication() {
        if hasAuthenticatonCompleted == true {
            coordinator.onAuthenticated()
        }
        hasAuthenticatonCompleted = true
    }
}
