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
import PDClient
#if os(iOS)
import ProtonCore_Challenge
#endif
import ProtonCore_Keymaker
import ProtonCore_Services
import ProtonCore_Authentication
import ProtonCore_Environment
import Reachability

public class InitialServices {
    public let keymaker: Keymaker
    public let clientConfig: Configuration
    
    public private(set) var sessionVault: SessionVault
    public private(set) var networkService: PMAPIService
    public private(set) var networkClient: PMAPIClient
    public private(set) var authenticator: Authenticator
    
    public var isLoggedIn: Bool {
        self.sessionVault.clientCredential() != nil
    }
    
    public init(clientConfig: Configuration, keymaker: Keymaker) {
        self.keymaker = keymaker
        self.clientConfig = clientConfig

        let (sessionVault, networking, serviceDelegate, authenticator) = Self.makeServices(clientConfig: clientConfig, and: keymaker)

        self.sessionVault = sessionVault
        self.networkService = networking
        self.networkClient = serviceDelegate
        self.authenticator = authenticator
    }

    public func clearCache() {
        let (sessionVault, networking, serviceDelegate, authenticator) = Self.makeServices(clientConfig: clientConfig, and: keymaker)

        self.sessionVault = sessionVault
        self.networkService = networking
        self.networkClient = serviceDelegate
        self.authenticator = authenticator
    }

    // swiftlint:disable large_tuple
    private static func makeServices(clientConfig: Configuration, and keymaker: Keymaker) -> (SessionVault, PMAPIService, PMAPIClient, Authenticator) {
        let sessionVault = SessionVault(mainKeyProvider: keymaker)
        let serviceDelegate = PMAPIClient(
            version: clientConfig.clientVersion,
            sessionVault: sessionVault,
            authenticator: nil
        )
#if os(iOS)
        let networking = PMAPIService.createAPIService(environment: clientConfig.environment,
                                                       sessionUID: sessionVault.credential?.UID ?? "",
                                                       challengeParametersProvider: .forAPIService(clientApp: .drive))
#else
        let networking = PMAPIService.createAPIService(environment: clientConfig.environment,
                                                       sessionUID: sessionVault.credential?.UID ?? "",
                                                       challengeParametersProvider: .empty)
#endif
        networking.serviceDelegate = serviceDelegate
        networking.authDelegate = serviceDelegate

        let authenticator = Authenticator(api: networking)

        // Important: this human delegate will be replaced by Core team's HumanCheckHelper in the iOS app
        networking.humanDelegate = serviceDelegate
        networking.forceUpgradeDelegate = serviceDelegate

        serviceDelegate.apiService = networking
        serviceDelegate.authenticator = authenticator
        serviceDelegate.generalReachability = try? Reachability(hostname: clientConfig.host)

        return (sessionVault, networking, serviceDelegate, authenticator)
    }
}
