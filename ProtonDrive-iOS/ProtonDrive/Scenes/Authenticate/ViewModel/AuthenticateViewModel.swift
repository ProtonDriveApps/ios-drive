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

public final class AuthenticateViewModel {

    private let sessionStore: SessionStore
    private let sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    private let coordinator: AuthenticateCoordinator
    private var hasAuthenticatonCompleted = false

    init(sessionStore: SessionStore,
         sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
         coordinator: AuthenticateCoordinator) {
        self.sessionStore = sessionStore
        self.sessionCommunicator = sessionCommunicator
        self.coordinator = coordinator
    }

    var welcomeBody: String {
        "The convenience of cloud storage and the security of encryption technology. Finally a cloud storage solution you can trust."
    }

    func save(_ userData: UserData, _ errorBlock: @escaping (Error) -> Void) {
        #if DEBUG
            dump("Credential 🔑: \n \(userData.credential)")
        #endif

        let parentSessionCredential = Credential(userData.credential, scopes: userData.scopes)
        sessionCommunicator
            .fetchNewChildSession(parentSessionCredential: parentSessionCredential) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.sessionStore.storeCredential(CoreCredential(parentSessionCredential))
                    self.sessionStore.storeUser(userData.user)
                    self.sessionStore.storeAddresses(userData.addresses)
                    self.sessionStore.storePassphrases(userData.passphrases)
                    self.completeAuthentication()
                    self.sessionCommunicator.onChildSessionReady()
                case .failure(let error):
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
