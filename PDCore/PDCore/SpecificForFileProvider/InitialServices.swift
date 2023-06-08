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
import OSLog
import PDClient
#if os(iOS)
import ProtonCore_Challenge
#endif
import ProtonCore_FeatureSwitch
import ProtonCore_Keymaker
import ProtonCore_Services
import ProtonCore_Authentication
import ProtonCore_Observability
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

        if FeatureFactory.shared.isEnabled(.unauthSession) {
            networkService.acquireSessionIfNeeded { result in
                switch result {
                case .success:
                    // session was already available, or servers were
                    // reached but returned 4xx/5xx.
                    // In both cases we're done here
                    break
                case .failure(let error):
                    // servers not reachable, need to display banner
                    ConsoleLogger.shared?.log(error, osLogType: SessionVault.self)
                }
            }
        }
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
        let networking = PMAPIService.createAPIServiceWithoutSession(environment: clientConfig.environment,
                                                                     challengeParametersProvider: .forAPIService(clientApp: .drive,
                                                                                                                 challenge: PMChallenge()))
#else
        let networking = PMAPIService.createAPIServiceWithoutSession(environment: clientConfig.environment,
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

        ObservabilityEnv.current.setupWorld(requestPerformer: networking)

        return (sessionVault, networking, serviceDelegate, authenticator)
    }
}
