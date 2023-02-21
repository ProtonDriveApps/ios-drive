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
import os.log
import GoLibs
import ProtonCore_Keymaker
import ProtonCore_Authentication
import ProtonCore_DataModel
import PDClient
import Combine

public class SessionVault: CredentialProvider, LogObject, ObservableObject {
    public typealias Salt = ProtonCore_DataModel.KeySalt
    public typealias AddressID = String
    public typealias Key = ProtonCore_DataModel.Key
    
    public enum Errors: Error {
        case noRequiredAddressKey, noRequiredPassphrase
        case passphrasesVaultEmpty, saltsVaultEmpty
        case addressNotFound
        case addressHasNoActiveKeys
    }

    public static var osLog: OSLog = OSLog(subsystem: "PDCore", category: "SessionVault")
    static var current: SessionVault! // 🧨
    internal var mainKeyProvider: MainKeyProvider!
    
    @SecureStorage(label: "credential") private(set) var credential: CoreCredential?
    @SecureStorage(label: "salts") private(set) var salts: [Salt]?
    @SecureStorage(label: "passphrases", caching: Constants.runningInExtension) private(set) var passphrases: [AddressID: String]?
    @SecureStorage(label: "publicKeys", caching: Constants.runningInExtension) private(set) var publicKeys: [String: [PublicKey]]?
    @SecureStorage(label: "addresses", caching: Constants.runningInExtension) private(set) var addresses: [Address]? {
        didSet { objectWillChange.send() }
    }
    @SecureStorage(label: "userInfo") private(set) var userInfo: User? {
        didSet { objectWillChange.send() }
    }
    
    public init(mainKeyProvider: MainKeyProvider) {
        self.mainKeyProvider = mainKeyProvider
        
        self._credential.configure(with: mainKeyProvider, logger: SessionVault.self)
        self._userInfo.configure(with: mainKeyProvider, logger: SessionVault.self)
        self._salts.configure(with: mainKeyProvider, logger: SessionVault.self)
        self._passphrases.configure(with: mainKeyProvider, notifying: true, logger: SessionVault.self)
        self._addresses.configure(with: mainKeyProvider, notifying: true, logger: SessionVault.self)
        self._publicKeys.configure(with: mainKeyProvider, notifying: true, logger: SessionVault.self)
        
        Self.current = self
    }
    
    func set(passphrases: [AddressID: String]) {
        storePassphrases(passphrases)
    }

    public func isSignedIn() -> Bool {
        self._credential.hasCyphertext()
    }
    
    public func clientCredential() -> PDClient.ClientCredential? {
        guard let credential = self.credential else { return nil }
        return .init(credential)
    }
}

extension SessionVault: SessionStore {
    public var sessionCredential: CoreCredential? {
         credential
    }

    public func storeCredential(_ credential: CoreCredential) {
        self.credential = credential
    }

    public func storeUser(_ user: User) {
        self.userInfo = user
    }
    
    public func storeSalts(_ salts: [KeySalt]) {
        self.salts = salts
    }

    public func storeAddresses(_ addresses: [Address]) {
        self.addresses = addresses
        var keys = [String: [PublicKey]]()
        for address in addresses {
            keys[address.email.canonicalForm] = address.activePublicKeys
        }
        self.publicKeys = keys
    }

    public func storePassphrases(_ passphrases: [AddressID: Passphrase]) {
        self.passphrases = passphrases
    }

    public func signOut() {
        _credential.wipeValue()
        _userInfo.wipeValue()
        _salts.wipeValue()
        _passphrases.wipeValue()
        _addresses.wipeValue()
        
        mainKeyProvider.wipeMainKey()
    }
}

public protocol SessionStore {
    typealias AddressID = String

    var sessionCredential: CoreCredential? { get }

    func storeCredential(_ credential: CoreCredential)
    func storeUser(_ user: User)
    func storeSalts(_ salts: [KeySalt])
    func storeAddresses(_ addresses: [Address])
    func storePassphrases(_ passphrases: [AddressID: Passphrase])
    
    func signOut()
}

extension SessionVault {
    internal func validateMailboxPassword(_ addresses: [Address], _ userKeys: [Key]) -> Bool {
        var isValid = false
        
        // old keys - address keys
        self.passphrases?.forEach { keyID, passphrase in
            addresses.map(\.keys)
                .reduce([Key](), {
                var new = $0
                new.append(contentsOf: $1)
                return new
            })
            .filter { $0.keyID == keyID }
            .map { $0.privateKey }
            .forEach { privateKey in
                var error: NSError?
                let armored = CryptoNewKeyFromArmored(privateKey, &error)
                
                do {
                    try armored?.unlock(Data(passphrase.utf8))
                    isValid = true
                } catch {
                    // do nothing
                }
            }
        }
        
        // new keys - user keys
        self.passphrases?.forEach { keyID, passphrase in
            userKeys.filter { $0.keyID == keyID }
            .map(\.privateKey)
            .forEach { privateKey in
                var error: NSError?
                let armored = CryptoNewKeyFromArmored(privateKey, &error)
                
                do {
                    try armored?.unlock(Data(passphrase.utf8))
                    isValid = true
                } catch {
                    // do nothing
                }
            }
        }
        
        return isValid
    }
    
    func userPassphrase() throws -> String {
        guard let passphrases = self.passphrases, let userInfo = self.userInfo else {
            throw Errors.passphrasesVaultEmpty
        }
        for userKey in userInfo.keys {
            if let passphrase = passphrases[userKey.keyID] {
                return passphrase
            }
        }
        throw Errors.noRequiredPassphrase
    }
    
    func addressPassphrase(for addressKey: Key) throws -> String {
        guard let userInfo = self.userInfo else {
            throw Errors.passphrasesVaultEmpty
        }
        let userPassphrase = try self.userPassphrase()
        let addressKeyPassphrase = try addressKey._passphrase(userKeys: userInfo.keys, mailboxPassphrase: userPassphrase)
        return addressKeyPassphrase
    }
    
    private func userKeyAndPassphrase(for addressKey: Key) throws -> (Key, String) {
        guard let passphrases = self.passphrases, let userInfo = self.userInfo else {
            throw Errors.passphrasesVaultEmpty
        }
        let userKeysWithPassphrases = Set(passphrases.map(\.key)).intersection(Set(userInfo.keys.map(\.keyID)))
        guard let userKey = self.userInfo?.keys.first(where: { userKeysWithPassphrases.contains($0.keyID) }),
            let passphrase = passphrases[userKey.keyID] else
        {
            throw Errors.noRequiredPassphrase
        }
        return (userKey, passphrase)
    }
    
    func makePassphrases(mailboxPassword: String) throws {
        var error: NSError?
        
        guard let salts = self.salts else {
            throw Errors.saltsVaultEmpty
        }
        
        let passphrases = salts.filter {
            $0.keySalt != nil
        }.map { salt -> (AddressID, String)? in
            let keySalt = salt.keySalt!
            
            let saltPackage = Data(base64Encoded: keySalt, options: NSData.Base64DecodingOptions(rawValue: 0))
            guard let passphraseUncut = SrpMailboxPassword(mailboxPassword.data(using: .utf8), saltPackage, &error) else {
                return nil
            }
            
            // by some internal reason of go-srp, output will be 60 characters but we need only last 31 of them
            guard let passphrase = String(data: passphraseUncut, encoding: .utf8)?.suffix(31) else {
                return nil
            }
            
            return (salt.ID, String(passphrase))
        }
        .compactMap { $0 }
        
        guard error == nil else {
            throw error!
        }
        
        self.set(passphrases: Dictionary(passphrases, uniquingKeysWith: { one, two in one }))
    }
}

extension SessionVault {
    public var addressIDs: Set<String> {
        let currentAddresses = addresses ?? []
        return Set(currentAddresses.map(\.addressID))
    }

    public func currentAddress() -> Address? {
        guard let email = self.userInfo?.email else {
            assert(false, "Drive can not work with accounts without emails - they are needed for cryptography")
            return nil
        }
        return self.getAddress(for: email)
    }
    
    public func currentCreator() -> String? {
        self.currentAddress()?.email
    }

    public func getAddress(for email: String) -> Address? {
        let canonicalForm = email.canonicalForm
        return self.addresses?.first(where: { $0.email.canonicalForm == canonicalForm })
    }
    
    internal func getPublicKeys(for email: String) -> [PublicKey] {
        guard let cachedPublicKeys = publicKeys else {
            // fallback for legacy users who logged in before publicKeys caching was introduced
            return getAddress(for: email)?.activePublicKeys ?? []
        }
        return cachedPublicKeys[email.canonicalForm] ?? []
    }
    
    public func getAccountInfo() -> AccountInfo? {
        guard let info = self.userInfo else {
            return nil
        }
        let email = info.email ?? ""
        let name = info.displayName?.toNilIfEmpty ?? info.name ?? ""
        return .init(email: email, displayName: name)
    }
    
    public func getUserInfo() -> UserInfo? {
        guard let info = self.userInfo else {
            return nil
        }
        return .init(usedSpace: info.usedSpace, maxSpace: info.maxSpace, invoiceState: InvoiceUserState(rawValue: info.delinquent) ?? .onTime)
    }
}

private extension String {
    var canonicalForm: String {
        self.replacingOccurrences(of: "[-_.]", with: "", options: [.regularExpression])
            .lowercased()
    }
    
    var toNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public struct AccountInfo: Equatable {
    public let email: String
    public let displayName: String

    public init(email: String, displayName: String) {
        self.email = email
        self.displayName = displayName
    }

}

public struct UserInfo: Equatable {
    public let usedSpace: Double
    public let maxSpace: Double
    public let invoiceState: InvoiceUserState

    public init(usedSpace: Double, maxSpace: Double, invoiceState: InvoiceUserState) {
        self.usedSpace = usedSpace
        self.maxSpace = maxSpace
        self.invoiceState = invoiceState
    }

    public var availableStorage: Int {
        max(0, Int(maxSpace - usedSpace))
    }
    
    public var isDelinquent: Bool {
        switch invoiceState {
        case .onTime, .overdueEasy, .overdueMedium:
            return false
        case .delinquentMedium, .delinquentSevere:
            return true   
        }
    }
}

extension SessionVault.Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noRequiredAddressKey: return "Could not find required Address Key locally"
        case .noRequiredPassphrase: return "Could not find required Passphrase locally"
        case .passphrasesVaultEmpty: return "Could not find any Passphrases locally"
        case .saltsVaultEmpty: return "Could not find any Salts locally"
        case .addressNotFound: return "Could not find Address for the specified email"
        case .addressHasNoActiveKeys: return "Could not find any active key in the Address"
        }
    }
}

public enum InvoiceUserState: Int {
    case onTime = 0 // the invoice is paid
    case overdueEasy = 1 // unpaid invoice available for 7 days or less
    case overdueMedium = 2 // unpaid invoice with payment overdue for more than 7 days
    case delinquentMedium = 3 // unpaid invoice with payment overdue for more than 14 days, the user is considered Delinquent
    case delinquentSevere = 4 // unpaid invoice with payment not received for more than 30 days, the user is considered Delinquent
}
