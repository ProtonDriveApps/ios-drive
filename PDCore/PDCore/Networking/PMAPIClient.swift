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
import ProtonCore_Authentication
import ProtonCore_DataModel
import ProtonCore_HumanVerification
import ProtonCore_Services
import ProtonCore_Networking
import GoLibs
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
    
    internal var generalReachability: Reachability?
    internal var authenticator: AuthenticatorInterface?
    internal var apiService: PMAPIService?

    public weak var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    public weak var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    public weak var authSessionInvalidatedDelegateForLoginAndSignup: AuthSessionInvalidatedDelegate?

    // To be observed by UI layer in order to communicate with the user
    @objc public internal(set) dynamic var currentActivity: NSUserActivity = Activity.none

    init(version: String, sessionVault: SessionStore, authenticator: AuthenticatorInterface? = nil) {
        self.appVersion = version
        self.sessionStore = sessionVault
        self.authenticator = authenticator
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(downgradeTrustKitRestrictions), name: Self.downgradeTrustKit, object: nil)
        TrustKitFactory.make(isHardfail: true, delegate: self)
    }

    public var userAgent: String? {
        #if os(iOS)
        return "ProtonDrive/\(Bundle.main.majorVersion) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion); \(self.deviceName()))"
        #elseif os(macOS)
        return "ProtonDrive/\(Bundle.main.majorVersion) (macOS \(ProcessInfo.processInfo.operatingSystemVersionString); \(DarwinVersion()))"
        #endif
    }

    public var locale: String {
        Locale.autoupdatingCurrent.identifier
    }

    public func onUpdate(serverTime: Int64) {
        ConsoleLogger.shared?.log("Server time update from PMCommon: \(serverTime)", osLogType: Tower.self)
        CryptoUpdateTime(serverTime)
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
        apiService?.getSession()?.setChallenge(noTrustKit: false, trustKit: newTrustKit)
    }
}

extension PMAPIClient: AuthDelegate {

    public func onSessionObtaining(credential: ProtonCore_Networking.Credential) {
        let coreCredential = CoreCredential(credential)
        ConsoleLogger.shared?.log("Session obtained", osLogType: Tower.self)
        self.sessionStore.storeCredential(coreCredential)
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
        ConsoleLogger.shared?.log("Authenticated session invalidated from PMCommon", osLogType: Tower.self)
        self.currentActivity = Activity.logout
    }

    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
        ConsoleLogger.shared?.log("Unauthenticated session invalidated from PMCommon", osLogType: Tower.self)
        eraseSessionCredentials(sessionUID: sessionUID)
    }

    public enum Activity {
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
        ConsoleLogger.shared?.log("Update credential callback from PMCommon", osLogType: Tower.self)
        self.sessionStore.storeCredential(CoreCredential(auth))
    }
    
    public func onLogout(sessionUID uid: String) {
        ConsoleLogger.shared?.log("Logout callback from PMCommon", osLogType: Tower.self)
        self.currentActivity = Activity.logout
    }

    public func onForceUpgrade() {
        ConsoleLogger.shared?.log("ForceUpgrade callback from PMCommon", osLogType: Tower.self)
        self.currentActivity = Activity.forceUpgrade
    }

    private func eraseSessionCredentials(sessionUID: String) {
        guard self.sessionStore.sessionCredential != nil else { return }
        self.sessionStore.removeCredential()
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
    public func onForceUpgrade(message: String) {
        self.onForceUpgrade()
    }
}

extension PMAPIClient: TrustKitFailureDelegate {
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

extension PDClient.ClientCredential {
    var coreCredential: PDCore.CoreCredential {
        CoreCredential(
            UID: self.UID,
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            expiration: self.expiration,
            userName: self.userName,
            userID: self.userID,
            scope: self.scope
        )
    }
}
