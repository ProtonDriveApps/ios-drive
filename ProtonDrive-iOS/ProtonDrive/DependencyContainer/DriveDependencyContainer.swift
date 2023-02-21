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

import Sentry
import PDCore
import ProtonCore_Keymaker
import ProtonCore_Authentication
import ProtonCore_Services

public class DriveDependencyContainer {
    private let initialServices: InitialServices

    var appGroup: SettingsStorageSuite { Constants.appGroup }
    var authenticatedContainer: AuthenticatedDependencyContainer?
    var windowScene: UIWindowScene!

    public init() {
        func makeInitialServices() -> InitialServices {
            let config = Constants.clientApiConfig
            let autolocker = Autolocker(lockTimeProvider: DriveKeychain())
            let keymaker = Keymaker(autolocker: autolocker, keychain: DriveKeychain())
            return InitialServices(clientConfig: config, keymaker: keymaker)
        }

        initialServices = makeInitialServices()
    }

    var sessionVault: SessionVault {
        initialServices.sessionVault
    }
    
    var networkClient: PMAPIClient {
        initialServices.networkClient
    }

    var keymaker: Keymaker {
        initialServices.keymaker
    }

    var authenticator: Authenticator {
        initialServices.authenticator
    }

    var networkService: PMAPIService {
        initialServices.networkService
    }
}
