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

import PDClient
import Reachability
import ProtonCoreAuthentication
import ProtonCoreDataModel
import ProtonCoreEnvironment
import ProtonCoreFeatureFlags
import ProtonCoreServices
import ProtonCoreNetworking
import ProtonCoreCryptoGoInterface
import ProtonCoreKeymaker
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public typealias Configuration = PDClient.APIService.Configuration

public class PMAPIClient: NSObject, APIServiceDelegate {
    public static let downgradeTrustKit: NSNotification.Name = .init("ch.protondrive.PDCore.downgradeTrustKit")

    public let appVersion: String
    public var additionalHeaders: [String: String]? { nil }
    
    internal let sessionStore: SessionStore
    
    internal let generalReachability: Reachability?
    internal let authenticator: AuthenticatorInterface
    internal let apiService: ProtonCoreServices.APIService
    internal private(set) var sessionRelatedCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions

    private let observationCenter: UserDefaultsObservationCenter

    public weak var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    public weak var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    public weak var authSessionInvalidatedDelegateForLoginAndSignup: AuthSessionInvalidatedDelegate?
    private weak var autoLocker: Autolocker?

    // To be observed by UI layer in order to communicate with the user
    @objc public internal(set) dynamic var currentActivity: NSUserActivity = Activity.none
    
    @SettingsStorage(UserDefaults.NotificationPropertyKeys.cryptoServerTime.rawValue) var cryptoServerTime: TimeInterval?

    init(version: String,
         sessionVault: SessionStore,
         apiService: ProtonCoreServices.APIService,
         authenticator: AuthenticatorInterface,
         generalReachability: Reachability?,
         sessionRelatedCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
         autoLocker: Autolocker?,
         settingsStorage: SettingsStorageSuite = .group(named: Constants.appGroup)) {
        self.appVersion = version
        self.sessionStore = sessionVault
        self.apiService = apiService
        self.authenticator = authenticator
        self.generalReachability = generalReachability
        self.autoLocker = autoLocker
        self.sessionRelatedCommunicator = sessionRelatedCommunicator
        self.observationCenter = UserDefaultsObservationCenter(userDefaults: settingsStorage.userDefaults)
        super.init()
        _cryptoServerTime.configure(with: settingsStorage)
        if let cryptoServerTime {
            CryptoGo.CryptoUpdateTime(Int64(cryptoServerTime))
        }
        observationCenter.addObserver(self, of: \.cryptoServerTime) { value in
            guard let value else { return }
            CryptoGo.CryptoUpdateTime(Int64(value))
        }
        NotificationCenter.default.addObserver(self, selector: #selector(downgradeTrustKitRestrictions), name: Self.downgradeTrustKit, object: nil)
    }
    
    deinit {
        observationCenter.removeObserver(self)
    }

    public var userAgent: String? {
        #if os(iOS)
        return "ProtonDrive/\(Bundle.main.majorVersion) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion); \(self.deviceName()))"
        #elseif os(macOS)
        return "ProtonDrive/\(Bundle.main.majorVersion) (\(ProcessInfo.processInfo.operatingSystemVersion.description); \(DarwinVersion()))"
        #endif
    }

    public var locale: String {
        Locale.autoupdatingCurrent.identifier
    }

    public func onUpdate(serverTime: Int64) {
        cryptoServerTime = TimeInterval(serverTime)
    }

    public func isReachable() -> Bool {
        guard let reachability = generalReachability else {
            assertionFailure("General reachability was not injected into PMAPIClient")
            return true
        }

        return reachability.connection != .unavailable
    }

    public func onDohTroubleshot() {
        /* nothing */
    }

    @objc func downgradeTrustKitRestrictions() {
        let newTrustKit = TrustKitFactory.make(isHardfail: false, delegate: self)
        apiService.getSession()?.setChallenge(noTrustKit: false, trustKit: newTrustKit)
    }
}

extension PMAPIClient: AuthDelegate {

    public func onSessionObtaining(credential: ProtonCoreNetworking.Credential) {
        let coreCredential = CoreCredential(credential)
        Log.info("Session obtained", domain: .networking)
        self.sessionStore.storeCredential(coreCredential)
        refreshFeatureFlags(for: credential.userID)
    }

    public func onAdditionalCredentialsInfoObtained(sessionUID: String, password: String?, salt: String?, privateKey: String?) {
        guard let credential = credential(sessionUID: sessionUID) else { return }
        let authCredential = AuthCredential(credential)

        if let password = password {
            authCredential.update(password: password)
        }
        let saltToUpdate = salt ?? authCredential.passwordKeySalt
        let privateKeyToUpdate = privateKey ?? authCredential.privateKey
        authCredential.update(salt: saltToUpdate, privateKey: privateKeyToUpdate)

        self.sessionStore.storeCredential(CoreCredential(authCredential: authCredential, scopes: credential.scopes))
    }

    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
        if let autoLocker, autoLocker.shouldAutolockNow() {
            Log.debug("Ignore session invalidation because auto locker is enabled", domain: .networking)
            return
        }
        sessionStore.removeAuthenticatedCredential()
        apiService.setSessionUID(uid: "")
        Task {
            await sessionRelatedCommunicator.askMainAppToProvideNewChildSession()
        }
        if Constants.runningInExtension {
            Log.info("""
                     Authenticated session invalidated in the extension.
                     Clears the child session storage and asks the main app for the new session.
                     """,
                     domain: .networking)
            self.currentActivity = Activity.childSessionExpired
        } else {
            Log.info("Authenticated session invalidated in the main app. Logout!", domain: .networking)
            self.currentActivity = Activity.logout
        }
    }

    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
        Log.info("Unauthenticated session invalidated from PMCommon", domain: .networking)
        self.sessionStore.removeUnauthenticatedCredential()
        apiService.acquireSessionIfNeeded { _ in }
    }

    public enum Activity {
        public static let childSessionExpired: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.ChildSessionExpired")
        public static let logout: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.Logout")
        public static let humanVerification: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.HumanVerification")
        public static let forceUpgrade: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.ForceUpgrade")
        public static let trustKitFailure: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.TrustKitFailure")
        public static let trustKitFailureHard: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.TrustKitFailureHard")
        public static let none: NSUserActivity = NSUserActivity(activityType: "ch.protondrive.PDCore.Tower.None")
    }
    
    internal enum Errors: Error {
        case noCredentialToRefresh, unexpectedResponse
    }

    public func authCredential(sessionUID uid: String) -> AuthCredential? {
        guard let credential = credential(sessionUID: uid) else { return nil }
        return AuthCredential(credential)
    }
    
    public func credential(sessionUID: String) -> Credential? {
        guard let coreCredential = self.sessionStore.sessionCredential else { return nil }
        let networkCredential = NetworkingCredential(coreCredential)
        return networkCredential
    }
    
    public func onUpdate(credential auth: Credential, sessionUID: String) {
        Log.info("Update credential callback from PMCommon", domain: .networking)
        self.sessionStore.storeCredential(CoreCredential(auth))
    }
}

extension PMAPIClient: HumanVerifyDelegate {
    /// This method should not be called from the iOS App only from App extensions and the macOS app. The iOS App uses Core team's
    /// the HumanCheckHelper class
    public func onDeviceVerify(parameters: DeviceVerifyParameters) -> String? {
        nil
    }

    /// This method should not be called from the iOS App only from App extensions and the macOS app. The iOS App uses Core team's
    /// the HumanCheckHelper class
    public func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: @escaping ((HumanVerifyFinishReason) -> Void)) {
        self.currentActivity = Activity.humanVerification

        completion(.verification(header: [:], verificationCodeBlock: nil))
    }
    
    public func getSupportURL() -> URL {
        Constants.humanVerificationSupportURL
    }
}

extension PMAPIClient: ForceUpgradeDelegate {
    public func onForceUpgrade(message _: String) {
        Log.info("ForceUpgrade callback from PMCommon", domain: .networking)
        self.currentActivity = Activity.forceUpgrade
    }
}

extension PMAPIClient: TrustKitDelegate {
    public func onTrustKitValidationError(_ error: TrustKitError) {
        switch error {
        case .hardfailed:
            self.currentActivity = Activity.trustKitFailureHard
        case .failed:
            self.currentActivity = Activity.trustKitFailure
        }
    }
}

extension PMAPIClient: AuthSessionInvalidatedDelegate {
    public func sessionWasInvalidated(for sessionUID: String, isAuthenticatedSession: Bool) {
        if isAuthenticatedSession {
            onAuthenticatedSessionInvalidated(sessionUID: sessionUID)
        } else {
            onUnauthenticatedSessionInvalidated(sessionUID: sessionUID)
        }
        authSessionInvalidatedDelegateForLoginAndSignup?.sessionWasInvalidated(for: sessionUID, isAuthenticatedSession: isAuthenticatedSession)
    }
}

// Copied from PMCommon.UserAgent, formatted in a way our client needs
extension PMAPIClient {
    // eg. iPhone5,2
    private func deviceName() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        if let dn = String(bytes: data, encoding: .ascii) {
            let ndn = dn.trimmingCharacters(in: .controlCharacters)
            return ndn
        }
        return "Unknown"
    }
    
    // eg. Darwin/16.3.0
    private func DarwinVersion() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        if let dv = String(bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii) {
            let ndv = dv.trimmingCharacters(in: .controlCharacters)
            return "Darwin/\(ndv)"
        }
        return ""
    }
}

extension PMAPIClient {
    private func refreshFeatureFlags(for userId: String) {
        ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.setUserId(userId)
        ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.setApiService(apiService)
        Task {
            try? await ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.fetchFlags()
        }
    }
}

private extension OperatingSystemVersion {
    var description: String {
        "macOS \(majorVersion).\(minorVersion).\(patchVersion)"
    }
}
