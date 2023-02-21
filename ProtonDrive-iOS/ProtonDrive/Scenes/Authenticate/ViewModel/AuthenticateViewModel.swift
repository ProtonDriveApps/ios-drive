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
import ProtonCore_Login

public final class AuthenticateViewModel {

    private let sessionStore: SessionStore

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var welcomeBody: String {
        "The convenience of cloud storage and the security of encryption technology. Finally a cloud storage solution you can trust."
    }

    func didAuthenticate(_ userData: UserData) {
        #if DEBUG
            dump("Credential 🔑: \n \(userData.credential)")
        #endif

        sessionStore.storeCredential(CoreCredential(authCredential: userData.credential, scopes: userData.scopes))
        sessionStore.storeUser(userData.user)
        sessionStore.storeSalts(userData.salts)
        sessionStore.storeAddresses(userData.addresses)
        sessionStore.storePassphrases(userData.passphrases)

        NotificationCenter.default.post(.checkAuthentication)
    }
}
