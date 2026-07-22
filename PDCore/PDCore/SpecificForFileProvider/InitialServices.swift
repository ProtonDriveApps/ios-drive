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
    public let mainKeyProvider: MainKeyProvider
    public let clientConfig: Configuration
    public let localSettings: LocalSettings

    public private(set) var sessionVault: SessionVault
    public private(set) var networkService: PMAPIService
    public private(set) var networkClient: PMAPIClient
    public private(set) var authenticator: Authenticator
    public private(set) var featureFlagsRepository: FeatureFlagsRepositoryProtocol
    public private(set) var sessionRelatedCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    public private(set) var pushNotificationService: PushNotificationServiceProtocol?
    public private(set) var connectionStateResource: ConnectionStateResource

    private let sessionRelatedCommunicatorFactory: SessionRelatedCommunicatorFactory

    public var isLoggedIn: Bool {
        self.sessionVault.isSignedIn()
    }

    public var isLoggedInPublisher: AnyPublisher<Bool, Never> {
        self.sessionVault.isSignedInPublisher
    }

    /// Convenience init for production use: creates a real network monitor.
    public convenience init(userDefault: UserDefaults,
                            clientConfig: Configuration,
                            mainKeyProvider: MainKeyProvider,
                            autoLocker: Autolocker?,
                            sessionRelatedCommunicatorFactory: @escaping SessionRelatedCommunicatorFactory,
                            isDetailedLoggingEnabled: (() -> Bool)? = nil) {
        let networking = Self.makeNetworking(environment: clientConfig.environment)
        let monitor = MonitorConnectionStateResource(doh: networking.dohInterface)
        #if os(iOS)
        monitor.startMonitoring()
        #endif
        #if DEBUG
        monitor.startObservingSimulationCommands()
        #endif
        self.init(
            userDefault: userDefault,
            clientConfig: clientConfig,
            mainKeyProvider: mainKeyProvider,
            autoLocker: autoLocker,
            sessionRelatedCommunicatorFactory: sessionRelatedCommunicatorFactory,
            connectionStateResource: monitor,
            networking: networking,
            isDetailedLoggingEnabled: isDetailedLoggingEnabled
        )
    }

    public init(userDefault: UserDefaults,
                clientConfig: Configuration,
                mainKeyProvider: MainKeyProvider,
                autoLocker: Autolocker?,
                sessionRelatedCommunicatorFactory: @escaping SessionRelatedCommunicatorFactory,
                connectionStateResource: ConnectionStateResource,
                networking: PMAPIService? = nil,
                isDetailedLoggingEnabled: (() -> Bool)? = nil) {
        self.userDefault = userDefault
        self.mainKeyProvider = mainKeyProvider
        self.clientConfig = clientConfig
        self.sessionRelatedCommunicatorFactory = sessionRelatedCommunicatorFactory
        self.localSettings = LocalSettings.shared

        let networking = networking ?? Self.makeNetworking(environment: clientConfig.environment)

        let (sessionVault, serviceDelegate, authenticator, communicator, featureFlagsRepository, pushNotificationService) =
            Self.makeServices(
                userDefault: userDefault,
                clientConfig: clientConfig,
                and: mainKeyProvider,
                using: sessionRelatedCommunicatorFactory,
                localSettings: localSettings,
                autoLocker: autoLocker,
                networking: networking
            )

        self.sessionVault = sessionVault
        self.networkService = networking
        self.networkClient = serviceDelegate
        self.authenticator = authenticator
        self.featureFlagsRepository = featureFlagsRepository
        self.sessionRelatedCommunicator = communicator
        self.connectionStateResource = connectionStateResource

        #if os(macOS)
        let detailedLoggingCheck = isDetailedLoggingEnabled ?? { false }
        let observabilityPerformer = ObservabilityConstrainedRequestPerformer(localSettings: localSettings, requestPerforming: networking)
        let observabilityInterceptor = ObservabilityInterceptingRequestPerformer(
            wrapped: observabilityPerformer,
            fileWriter: ObservabilityEventFileWriter.shared,
            isDetailedLoggingEnabled: detailedLoggingCheck
        )
        ObservabilityEnv.current.setupWorld(requestPerformer: observabilityInterceptor)
        #elseif os(iOS)
        self.pushNotificationService = pushNotificationService
        let observabilityPerformer = ObservabilityConstrainedRequestPerformer(localSettings: localSettings, requestPerforming: networking)
        ObservabilityEnv.current.setupWorld(requestPerformer: observabilityPerformer)

        #if DEBUG
        let isRunningUITests = DebugConstants.commandLineContains(flags: [.uiTests])
        #else
        let isRunningUITests = false
        #endif

        if !PDCore.Constants.runningInExtension, !isRunningUITests {
            TelemetryService.shared.setApiService(apiService: networking)
            TelemetryService.shared.setTelemetryEnabled(!(localSettings.optOutFromTelemetry ?? false))
        }
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
                Log.error(error: error, domain: .networking)
            }
        }
    }

    private static func makeNetworking(environment: ProtonCoreEnvironment.Environment) -> PMAPIService {
#if os(iOS)
        PMAPIService.createAPIServiceWithoutSession(environment: environment,
                                                    challengeParametersProvider: .forAPIService(clientApp: .drive,
                                                                                                challenge: PMChallenge()))
#else
        PMAPIService.createAPIServiceWithoutSession(environment: environment,
                                                    challengeParametersProvider: .empty)
#endif
    }

    // swiftlint:disable large_tuple
    // swiftlint:disable:next function_parameter_count
    private static func makeServices(
        userDefault: UserDefaults,
        clientConfig: Configuration,
        and mainKeyProvider: MainKeyProvider,
        using sessionRelatedCommunicatorFactory: SessionRelatedCommunicatorFactory,
        localSettings: LocalSettings,
        autoLocker: Autolocker?,
        networking: PMAPIService
    ) -> (SessionVault, PMAPIClient, Authenticator, SessionRelatedCommunicatorBetweenMainAppAndExtensions, FeatureFlagsRepositoryProtocol, PushNotificationServiceProtocol?) {
        let sessionVault = SessionVault(mainKeyProvider: mainKeyProvider)
        let authenticator = Authenticator(api: networking)

        let sessionRelatedCommunicator = sessionRelatedCommunicatorFactory(sessionVault, authenticator) { [weak networking] credential in
            networking?.setSessionUID(uid: credential.UID)
        }

        let serviceDelegate = PMAPIClient(
            version: clientConfig.clientVersion,
            sessionVault: sessionVault,
            apiService: networking,
            authenticator: authenticator,
            generalReachability: try? Reachability(hostname: clientConfig.apiOrigin),
            sessionRelatedCommunicator: sessionRelatedCommunicator,
            autoLocker: autoLocker
        )

        TrustKitFactory.make(isHardfail: true, delegate: serviceDelegate)

        networking.getSession()?.setChallenge(noTrustKit: PMAPIService.noTrustKit, trustKit: PMAPIService.trustKit)

        networking.serviceDelegate = serviceDelegate
        networking.authDelegate = serviceDelegate

        // Important: this human delegate will be replaced by Core team's HumanCheckHelper in the iOS app
        networking.humanDelegate = serviceDelegate
        networking.forceUpgradeDelegate = serviceDelegate

        // Override FF values for dynamic plans and easy device migration, after launch during services creation. Original override.
        let featureFlagsRepository = ProtonCoreFeatureFlags.FeatureFlagsRepository.shared
        featureFlagsRepository.setApiService(networking)
        let userID = sessionVault.userInfo?.ID
        featureFlagsRepository.setUserId(userID ?? "")
        featureFlagsRepository.setFlagOverride(CoreFeatureFlagType.dynamicPlan, true)
        featureFlagsRepository.resetFlagOverride(CoreFeatureFlagType.easyDeviceMigrationDisabled)
        Task {
            try? await featureFlagsRepository.fetchFlags()
        }
        
#if DEBUG
        let isRunningUITests = DebugConstants.commandLineContains(flags: [.uiTests])
#else
        let isRunningUITests = false
#endif
        
#if os(iOS)
        if !PDCore.Constants.runningInExtension, !isRunningUITests {
            let pushNotificationService = PushNotificationService(apiService: networking)
            pushNotificationService.setup()
        }
#endif
        let pushNotificationService: PushNotificationServiceProtocol? = nil

        Task {
            await sessionRelatedCommunicator.performInitialSetup()
        }

        return (sessionVault, serviceDelegate, authenticator, sessionRelatedCommunicator, featureFlagsRepository, pushNotificationService)
    }
    // swiftlint:enable large_tuple
}

public protocol hasPushNotificationService {
    var pushNotificationService: PushNotificationServiceProtocol? { get set }
}
