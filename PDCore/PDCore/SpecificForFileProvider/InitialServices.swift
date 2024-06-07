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

import Combine
import Foundation
import OSLog
import PDClient
#if os(iOS)
import ProtonCoreChallenge
#endif
import ProtonCoreFeatureFlags
import ProtonCoreKeymaker
import ProtonCoreServices
import ProtonCoreAuthentication
import ProtonCoreObservability
import ProtonCorePushNotifications
import ProtonCoreEnvironment
import ProtonCoreTelemetry
import Reachability

public class InitialServices {
    public let userDefault: UserDefaults
    public let keymaker: Keymaker
    public let clientConfig: Configuration
    public let localSettings: LocalSettings

    public private(set) var sessionVault: SessionVault
    public private(set) var networkService: PMAPIService
    public private(set) var networkClient: PMAPIClient
    public private(set) var authenticator: Authenticator
    public private(set) var featureFlagsRepository: FeatureFlagsRepositoryProtocol
    public private(set) var sessionRelatedCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    public private(set) var pushNotificationService: PushNotificationServiceProtocol?

    private let sessionRelatedCommunicatorFactory: SessionRelatedCommunicatorFactory

    public var isLoggedIn: Bool {
        self.sessionVault.isSignedIn()
    }

    public var isLoggedInPublisher: AnyPublisher<Bool, Never> {
        self.sessionVault.isSignedInPublisher
    }
    
    public init(userDefault: UserDefaults,
                clientConfig: Configuration,
                keymaker: Keymaker,
                sessionRelatedCommunicatorFactory: @escaping SessionRelatedCommunicatorFactory) {
        self.userDefault = userDefault
        self.keymaker = keymaker
        self.clientConfig = clientConfig
        self.sessionRelatedCommunicatorFactory = sessionRelatedCommunicatorFactory
        self.localSettings = LocalSettings.shared

        let (sessionVault, networking, serviceDelegate, authenticator, communicator, featureFlagsRepository, pushNotificationService) =
            Self.makeServices(userDefault: userDefault, clientConfig: clientConfig, and: keymaker, using: sessionRelatedCommunicatorFactory, localSettings: localSettings)

        self.sessionVault = sessionVault
        self.networkService = networking
        self.networkClient = serviceDelegate
        self.authenticator = authenticator
        self.featureFlagsRepository = featureFlagsRepository
        self.sessionRelatedCommunicator = communicator
#if os(iOS)
        self.pushNotificationService = pushNotificationService
#endif

        networkService.acquireSessionIfNeeded { result in
            switch result {
            case .success:
                // session was already available, or servers were
                // reached but returned 4xx/5xx.
                // In both cases we're done here
                break
            case .failure(let error):
                // servers not reachable, need to display banner
                Log.error(error, domain: .networking)
            }
        }
    }

    // swiftlint:disable large_tuple
    private static func makeServices(
        userDefault: UserDefaults,
        clientConfig: Configuration,
        and keymaker: Keymaker,
        using sessionRelatedCommunicatorFactory: SessionRelatedCommunicatorFactory,
        localSettings: LocalSettings
    ) -> (SessionVault, PMAPIService, PMAPIClient, Authenticator, SessionRelatedCommunicatorBetweenMainAppAndExtensions, FeatureFlagsRepositoryProtocol, PushNotificationServiceProtocol?) {
        let sessionVault = SessionVault(mainKeyProvider: keymaker)
#if os(iOS)
        let networking = PMAPIService.createAPIServiceWithoutSession(environment: clientConfig.environment,
                                                                     challengeParametersProvider: .forAPIService(clientApp: .drive,
                                                                                                                 challenge: PMChallenge()))
#else
        let networking = PMAPIService.createAPIServiceWithoutSession(environment: clientConfig.environment,
                                                                     challengeParametersProvider: .empty)
#endif
        let authenticator = Authenticator(api: networking)

        let sessionRelatedCommunicator = sessionRelatedCommunicatorFactory(
            userDefault, sessionVault, authenticator, networking
        )

        let serviceDelegate = PMAPIClient(
            version: clientConfig.clientVersion,
            sessionVault: sessionVault,
            apiService: networking,
            authenticator: authenticator,
            generalReachability: try? Reachability(hostname: clientConfig.host),
            sessionRelatedCommunicator: sessionRelatedCommunicator
        )

        TrustKitFactory.make(isHardfail: true, delegate: serviceDelegate)

        networking.getSession()?.setChallenge(noTrustKit: PMAPIService.noTrustKit, trustKit: PMAPIService.trustKit)

        networking.serviceDelegate = serviceDelegate
        networking.authDelegate = serviceDelegate

        // Important: this human delegate will be replaced by Core team's HumanCheckHelper in the iOS app
        networking.humanDelegate = serviceDelegate
        networking.forceUpgradeDelegate = serviceDelegate

        let featureFlagsRepository = ProtonCoreFeatureFlags.FeatureFlagsRepository.shared
        featureFlagsRepository.setApiService(networking)
        
#if DEBUG
        let isRunningUITests = DebugConstants.commandLineContains(flags: [.uiTests])
#else
        let isRunningUITests = false
#endif
        
#if os(iOS)
        if !PDCore.Constants.runningInExtension, !isRunningUITests {
            let pushNotificationService = PushNotificationService(apiService: networking)
            Task {
                try? await featureFlagsRepository.fetchFlags()
                if featureFlagsRepository.isEnabled(CoreFeatureFlagType.pushNotifications) {
                    guard var delegate = await UIApplication.shared.delegate as? hasPushNotificationService else { return }
                    delegate.pushNotificationService = pushNotificationService
                    pushNotificationService.setup()
                }
            }
        }
#endif
        let pushNotificationService: PushNotificationServiceProtocol? = nil

        ObservabilityEnv.current.setupWorld(requestPerformer: networking)
#if os(iOS)
        if !PDCore.Constants.runningInExtension, !isRunningUITests {
            TelemetryService.shared.setApiService(apiService: networking)
            TelemetryService.shared.setTelemetryEnabled(!(localSettings.optOutFromTelemetry ?? false))
        }
#endif

        sessionRelatedCommunicator.performInitialSetup()

        return (sessionVault, networking, serviceDelegate, authenticator, sessionRelatedCommunicator, featureFlagsRepository, pushNotificationService)
    }
}

public protocol hasPushNotificationService {
    var pushNotificationService: PushNotificationServiceProtocol? { get set }
}
