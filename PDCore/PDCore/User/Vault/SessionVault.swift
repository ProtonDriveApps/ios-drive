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
import ProtonCoreCryptoGoInterface
import ProtonCoreKeymaker
import ProtonCoreAuthentication
import ProtonCoreDataModel
import PDClient
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

public class SessionVault: CredentialProvider, ObservableObject, ForeignKeysVault {
    public typealias AddressID = String
    public typealias Key = ProtonCoreDataModel.Key
    
    public enum Errors: Error {
        case noRequiredAddressKey, noRequiredPassphrase
        case passphrasesVaultEmpty
        case addressNotFound
        case addressHasNoActiveKeys
        case userNotFound
        case addressByIDNotFound
    }

    static var current: SessionVault! // 🧨
    private struct AddressKeysSnapshot: Equatable {
        let addressID: String
        let keys: [Key]
    }

    #if DEBUG
    internal var unlockedAddressPrivateKeyDerivationForTests: ((Key) throws -> Data)?
    #endif

    internal var mainKeyProvider: MainKeyProvider!
    private let unlockedAddressKeyCache: UnlockedAddressKeyCache
    private let stateLock = NSLock()
    
    // secure properties below must be only ever written to and read from the main app
    // the label differs from the property name to keep backwards compatibility with the older clients after property was renamed
    @SecureStorage(label: "parentSessionCredential") private var applicationParentSessionCredential: CoreCredential?
    
    // secure properties below must be only ever written to and read from the extension
    // the label differs from the property name to keep backwards compatibility with the older clients after property was renamed
    @SecureStorage(label: "fileProviderChildSessionCredential") private var fileProviderExtensionChildSessionCredential: CoreCredential?
    
    // secure properties below must be only ever written to from the main app and read from the extension (exception: migration path)
    // the label differs from the property name to keep backwards compatibility with the older clients after property was renamed
    @SecureStorage(label: "temporaryLockerStorageForChildSessionCredential") private var temporaryLockerStorageForFileProviderExtensionChildSessionCredential: CoreCredential?
    
    // a proxy property, passes info to the proper storage ones
    private var credential: CoreCredential? {
        get {
            if Constants.runningInExtension {
                return fileProviderExtensionChildSessionCredential
            } else {
                return applicationParentSessionCredential
            }
        }
        
        set {
            if Constants.runningInExtension {
                fileProviderExtensionChildSessionCredential = newValue
                if let newValue {
                    if Constants.buildType.isQaOrBelow {
                        Log.info("New child session credentials \(newValue.UID) stored in the extension",
                                 domain: .sessionManagement)
                    } else {
                        Log.info("New child session credentials stored in the extension",
                                 domain: .sessionManagement)
                    }
                } else {
                    Log.info("Child session credentials removed from storage in the extension",
                             domain: .sessionManagement)
                }
            } else {
                applicationParentSessionCredential = newValue
                if let newValue {
                    if Constants.buildType.isQaOrBelow {
                        Log.info("New parent session credentials \(newValue.UID) stored in the main app",
                                 domain: .sessionManagement)
                    } else {
                        Log.info("New parent session credentials stored in the main app",
                                 domain: .sessionManagement)
                    }
                } else {
                    Log.info("Parent session credentials removed from storage in the main app",
                             domain: .sessionManagement)
                    // inform about being signed out
                    objectWillChange.send()
                }
            }
        }
    }
    
    // the errSecDuplicateItem and errSecItemNotFound are allowed for the unauthorizedCredential
    // because they are shared between two processes: the app and the extension.
    // This can cause a race on write between them and result in
    // * a duplicate call to SecItemAdd. Such call will result in a errSecDuplicateItem error.
    // * data being removed at the same time as it's updated from other process. This will be errSecItemNotFound.
    // However, it doesn't matter which of the unauthorizedCredential we're gonna use (the one written from app
    // or the one written from extension), all we care is that it's the same one in both.
    // Similarly, it doesn't matter which process removes the unauthorizedCredential — it always means there's an auth session comming,
    // so the unauth session can be dropped. So we can just ignore the errors and move on, instead of crashing.
    @SecureStorage(label: "unauthorizedCredential", allowedKeychainWriteErrorCodes: [errSecDuplicateItem, errSecItemNotFound])
    private var unauthorizedCredential: CoreCredential?

    @SecureStorage(label: "passphrases", caching: Constants.runningInExtension) private(set) var passphrases: [AddressID: String]?
    @SecureStorage(label: "publicKeys", caching: Constants.runningInExtension) private(set) var publicKeys: [String: [PublicKey]]?
    @SecureStorage(label: "foreignPublicKeys", caching: Constants.runningInExtension) private(set) var foreignPublicKeys: [String: [PublicKey]]?
    @SecureStorage(label: "addressIDPublicKeys", caching: Constants.runningInExtension) private(set) var addressIDPublicKeys: [String: [PublicKey]]?
    @SecureStorage(label: "addresses", caching: Constants.runningInExtension) public private(set) var addresses: [Address]? {
        didSet { objectWillChange.send() }
    }
    @SecureStorage(label: "userInfo") public private(set) var userInfo: User? {
        didSet { objectWillChange.send() }
    }
    @SecureStorage(label: "uploadClientUID", caching: Constants.runningInExtension) private var uploadClientUID: String?
    @SecureStorage(label: "deviceUUID", caching: Constants.runningInExtension) private var deviceUUID: String?

    // QA only
    public var parentSessionUID: String? {
        applicationParentSessionCredential?.UID
    }
    // QA only
    public var childSessionUID: String? {
        (fileProviderExtensionChildSessionCredential ?? temporaryLockerStorageForFileProviderExtensionChildSessionCredential)?.UID
    }

    public init(
        mainKeyProvider: MainKeyProvider,
        dateResource: DateResource = PlatformCurrentDateResource(),
        timerResource: TimerResource = PlatformTimerResource(),
        unlockedAddressPrivateKeyCacheLifetime: TimeInterval = 10 * 60,
        unlockedAddressPrivateKeyDerivationWaitTimeout: DispatchTimeInterval = .seconds(5)
    ) {
        let cache = UnlockedAddressKeyCache(
            derivation: nil,
            dateResource: dateResource,
            timerResource: timerResource,
            lifetime: unlockedAddressPrivateKeyCacheLifetime,
            derivationWaitTimeout: unlockedAddressPrivateKeyDerivationWaitTimeout
        )
        self.unlockedAddressKeyCache = cache
        self.mainKeyProvider = mainKeyProvider
        // This ensures the main key is read from the keychain and loaded into memory early
        // in the app initialization process, before it's used for all the secrets property wrappers.
        _ = try? mainKeyProvider.mainKeyOrError
        
        if Constants.runningInExtension {
            self._fileProviderExtensionChildSessionCredential.configure(with: mainKeyProvider)
            self._temporaryLockerStorageForFileProviderExtensionChildSessionCredential.configure(with: mainKeyProvider)
        } else {
            self._applicationParentSessionCredential.configure(with: mainKeyProvider)
            self._temporaryLockerStorageForFileProviderExtensionChildSessionCredential.configure(with: mainKeyProvider)
            if Constants.buildType.isQaOrBelow {
                // in QA builds, we do read the child session to expose its UID. It doesn't happen in the release builds
                self._fileProviderExtensionChildSessionCredential.configure(with: mainKeyProvider)
            }
        }
        self._unauthorizedCredential.configure(with: mainKeyProvider)
        self._userInfo.configure(with: mainKeyProvider)
        self._passphrases.configure(with: mainKeyProvider, notifying: true)
        self._addresses.configure(with: mainKeyProvider, notifying: true)
        self._publicKeys.configure(with: mainKeyProvider, notifying: true)
        self._foreignPublicKeys.configure(with: mainKeyProvider, notifying: true)
        self._addressIDPublicKeys.configure(with: mainKeyProvider, notifying: true)
        self._uploadClientUID.configure(with: mainKeyProvider)
        self._deviceUUID.configure(with: mainKeyProvider)
        
        migrateFromOldCredentialsStorageToNewStorage()
        migrateSaltsStorage()
        
        Self.current = self
        cache.derivation = self
    }

    // MainKey is not necesserily available at this point, so we are only allowed to operate on **cypherdata** without decrypting it
    private func migrateFromOldCredentialsStorageToNewStorage() {
        @SecureStorage(label: "credential") var oldCredentialsStorage: CoreCredential?
        _oldCredentialsStorage.configure(with: mainKeyProvider)
        
        guard !_applicationParentSessionCredential.hasCyphertext() else {
            Log.debug("User has credentials in parentSessionCredential, skipping migration", domain: .encryption)
            return
        }
        guard !_fileProviderExtensionChildSessionCredential.hasCyphertext() else {
            Log.debug("User has credentials in fileProviderChildSessionCredential, skipping migration", domain: .encryption)
            return
        }
        guard !_temporaryLockerStorageForFileProviderExtensionChildSessionCredential.hasCyphertext() else {
            Log.debug("User has credentials in temporaryLockerStorageForChildSessionCredentials, skipping migration", domain: .encryption)
            return
        }
        guard _oldCredentialsStorage.hasCyphertext() else {
            Log.debug("User has no credentials in oldCredentialsStorage, skipping migration", domain: .encryption)
            return
        }
        
        do {
            Log.info("User has credentials in oldCredentialsStorage, attempting migration", domain: .encryption)
            try _oldCredentialsStorage.duplicate(to: _applicationParentSessionCredential.label)
            try _oldCredentialsStorage.duplicate(to: _fileProviderExtensionChildSessionCredential.label)
            try _oldCredentialsStorage.duplicate(to: _temporaryLockerStorageForFileProviderExtensionChildSessionCredential.label)
            try _oldCredentialsStorage.wipeValue()
            try _unauthorizedCredential.wipeValue()
            Log.info("Successfully complete migration of oldCredentialsStorage", domain: .encryption)
        } catch {
            Log
                .error(
                    "Migration from single session to parent+child session failed, will cause force logout",
                    error: error,
                    domain: .encryption
                )
        }
    }
    
    // Salts should not be stored any more, existing values should be removed from old storage
    private func migrateSaltsStorage() {
        typealias Salt = ProtonCoreDataModel.KeySalt
        @SecureStorage(label: "salts") var salts: [Salt]?
        _salts.configure(with: mainKeyProvider)
        
        guard _salts.hasCyphertext() else {
            Log.debug("User has no salts in storage, skip wiping", domain: .encryption)
            return
        }
        
        do {
            Log.info("User has salts in storage, attempting wiping", domain: .encryption)
            try _salts.wipeValue()
            Log.info("Successfully wiped Salts", domain: .encryption)
        } catch {
            Log.error("Wiping of salts failed, may cause leftovers in local storage", error: error, domain: .encryption)
        }
    }
    
    public func set(passphrases: [AddressID: String]) {
        storePassphrases(passphrases)
    }

    public func isSignedIn() -> Bool {
        /// `_parentSessionCredential` gets filled before we actually obtain userInfo
        /// `userInfo` is needed though for fetching addresses
        self._applicationParentSessionCredential.hasCyphertext() && _userInfo.hasCyphertext()
    }
    
    public var isSignedInPublisher: AnyPublisher<Bool, Never> {
        objectWillChange
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { [weak self] in
                self?.isSignedIn()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public func clientCredential() -> ClientCredential? {
        guard let credential = sessionCredential else { return nil }
        return .init(credential)
    }

    public func getCredential() throws -> ClientCredential {
        guard let credential = clientCredential() else {
            throw CredentialProviderError.missingCredential
        }
        return credential
    }
}

extension SessionVault: SessionStore {

    public func removeAuthenticatedCredential() {
        credential = nil
    }

    public func removeUnauthenticatedCredential() {
        unauthorizedCredential = nil
    }

    public var sessionCredential: CoreCredential? {
        if let credential {
            return credential
        }
        if let unauthorizedCredential {
            return unauthorizedCredential
        }
        Log.debug("Query session credential: no available credential", domain: .application)
        return nil
    }

    public func storeCredential(_ credentialToStore: CoreCredential) {
        if credentialToStore.isForUnauthenticatedSession {
            unauthorizedCredential = credentialToStore
        } else {
            // in a single user app, there's never a situation when we need to keep unauth credentials once we obtain auth credentials
            removeUnauthenticatedCredential()
            var credentialToStore = credentialToStore
            if credentialToStore.mailboxPassword.isEmpty {
                credentialToStore.mailboxPassword = credential?.mailboxPassword ?? ""
            }
            credential = credentialToStore
        }
    }
    
    public func storeNewChildSessionCredential(_ credentialToStore: CoreCredential) {
        guard !Constants.runningInExtension else {
            assertionFailure("""
                             This method must only ever be called from the main app.
                             It's the only place that has access to the parent session and therefore can fork new child session credential.
                             """)
            return
        }
        if Constants.buildType.isQaOrBelow {
            Log.info("New child session credentials \(credentialToStore.UID) stored to the locker in the main app",
                     domain: .sessionManagement)
        } else {
            Log.info("New child session credentials stored to the locker in the main app",
                     domain: .sessionManagement)
        }
        temporaryLockerStorageForFileProviderExtensionChildSessionCredential = credentialToStore
    }
    
    public func consumeChildSessionCredentials() {
        guard Constants.runningInExtension else {
            assertionFailure("""
                             This method must only ever be called from the extension.
                             It's the only place that has access to the child session storage.
                             """)
            return
        }
        guard let newChildSessionCredentials = temporaryLockerStorageForFileProviderExtensionChildSessionCredential else { return }
        if Constants.buildType.isQaOrBelow {
            Log.info("New child session credentials \(newChildSessionCredentials.UID) consumed in the extension",
                     domain: .sessionManagement)
        } else {
            Log.info("New child session credentials consumed in the extension",
                     domain: .sessionManagement)
        }
        fileProviderExtensionChildSessionCredential = newChildSessionCredentials
        temporaryLockerStorageForFileProviderExtensionChildSessionCredential = nil
    }
    
    public func storeUser(_ user: User) {
        stateLock.lock()
        defer { stateLock.unlock() }
        let keysChanged = userInfo?.keys != user.keys
        self.userInfo = user
        if keysChanged {
            clearUnlockedAddressPrivateKeyCache()
        }
    }

    public func storeAddresses(_ addresses: [Address]) {
        stateLock.lock()
        defer { stateLock.unlock() }
        let currentAddressKeys = Self.makeAddressKeysSnapshot(from: self.addresses)
        let newAddressKeys = Self.makeAddressKeysSnapshot(from: addresses)
        self.addresses = addresses
        var keys = [String: [PublicKey]]()
        for address in addresses {
            keys[address.email.canonicalEmailForm] = address.activePublicKeys
        }
        self.publicKeys = keys
        if currentAddressKeys != newAddressKeys {
            clearUnlockedAddressPrivateKeyCache()
        }
    }

    /// - Parameters:
    ///   - keys: [canonicalEmailForm: [public keys]]
    public func storeForeignPublicKeys(_ keys: [String: [PublicKey]]) {
        foreignPublicKeys = keys
    }

    public func storePassphrases(_ passphrases: [AddressID: Passphrase]) {
        stateLock.lock()
        defer { stateLock.unlock() }
        let passphrasesChanged = self.passphrases != passphrases
        self.passphrases = passphrases
        if passphrasesChanged {
            clearUnlockedAddressPrivateKeyCache()
        }
    }

    public func signOut() {
        stateLock.lock()
        defer { stateLock.unlock() }
        clearUnlockedAddressPrivateKeyCache()
        try? _applicationParentSessionCredential.wipeValue()
        try? _fileProviderExtensionChildSessionCredential.wipeValue()
        try? _temporaryLockerStorageForFileProviderExtensionChildSessionCredential.wipeValue()
        try? _unauthorizedCredential.wipeValue()
        try? _userInfo.wipeValue()
        try? _passphrases.wipeValue()
        try? _addresses.wipeValue()
        try? _uploadClientUID.wipeValue()
        try? _publicKeys.wipeValue()
        try? _foreignPublicKeys.wipeValue()
        try? _addressIDPublicKeys.wipeValue()
        #if os(iOS)
        try? mainKeyProvider.wipeMainKeyOrError()
        // Bug in ProtonCore, `wipeMainKeyOrError` doesn't clean up BioProtection encryption keys, while
        // `wipeMainKey` does. Wiping it fixes issue with invalid keys being used.
        // Can be removed once ProtonCore is adjusted.
        mainKeyProvider.wipeMainKey()
        #endif
        
        // inform observers about being signed out 
        objectWillChange.send()
    }
}

public protocol SessionStore {
    typealias AddressID = String

    var sessionCredential: CoreCredential? { get }

    func removeAuthenticatedCredential()
    func removeUnauthenticatedCredential()

    func storeCredential(_ credential: CoreCredential)
    func storeNewChildSessionCredential(_ childSessionCredential: CoreCredential)
    func consumeChildSessionCredentials()
    
    func storeUser(_ user: User)
    func storeAddresses(_ addresses: [Address])
    func storePassphrases(_ passphrases: [AddressID: Passphrase])
    func getUserPassphrase() throws -> String

    func signOut()
    func isSignedIn() -> Bool
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
                let armored = CryptoGo.CryptoNewKeyFromArmored(privateKey, &error)
                
                do {
                    _ = try armored?.unlock(Data(passphrase.utf8))
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
                let armored = CryptoGo.CryptoNewKeyFromArmored(privateKey, &error)
                
                do {
                    _ = try armored?.unlock(Data(passphrase.utf8))
                    isValid = true
                } catch {
                    // do nothing
                }
            }
        }
        
        return isValid
    }

    public func getUserPassphrase() throws -> String {
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
    
    public func addressPassphrase(for addressKey: Key) throws -> String {
        guard let userInfo = self.userInfo else {
            throw Errors.userNotFound
        }
        let userPassphrase = try getUserPassphrase()
        let addressKeyPassphrase = try addressKey._passphrase(userKeys: userInfo.keys, mailboxPassphrase: userPassphrase)
        return addressKeyPassphrase
    }

    public func updatePassphrases(for userKeys: [Key], mailboxPassphrase: String) throws {
        guard let passphrases = self.passphrases else {
            throw Errors.passphrasesVaultEmpty
        }

        var newPassphrases = passphrases
        for userKey in userKeys {
            newPassphrases[userKey.keyID] = mailboxPassphrase
        }
        storePassphrases(newPassphrases)
    }

    public func unlockedAddressPrivateKeyData(for key: Key) throws -> Data {
        return try unlockedAddressKeyCache.unlockedAddressPrivateKeyData(for: key)
    }

    func cachedUnlockedAddressPrivateKey(for key: Key) -> Data? {
        return unlockedAddressKeyCache.cachedUnlockedAddressPrivateKey(for: key)
    }

    func cacheUnlockedAddressPrivateKey(_ data: Data, for key: Key) {
        unlockedAddressKeyCache.cacheUnlockedAddressPrivateKey(data, for: key)
    }

    func clearUnlockedAddressPrivateKeyCache() {
        unlockedAddressKeyCache.clear()
    }

    private static func makeAddressKeysSnapshot(from addresses: [Address]?) -> [AddressKeysSnapshot] {
        (addresses ?? []).map { address in
            AddressKeysSnapshot(addressID: address.addressID, keys: address.keys)
        }
    }
}

extension SessionVault: UnlockedAddressKey {
    public func deriveUnlockedAddressPrivateKeyData(for key: Key) throws -> Data {
        #if DEBUG
        if let unlockedAddressPrivateKeyDerivationForTests {
            return try unlockedAddressPrivateKeyDerivationForTests(key)
        }
        #endif
        let lockedAddressKey = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(key.privateKey, &$0) }
        let decryptedAddressPassphrase = try addressPassphrase(for: key)
        let unlockedAddressKey = try lockedAddressKey.unlock(decryptedAddressPassphrase.data(using: .utf8))
        return try unlockedAddressKey.serialize()
    }
}

extension SessionVault {
    public var addressIDs: Set<String> {
        let currentAddresses = addresses ?? []
        return Set(currentAddresses.map(\.addressID))
    }

    public func currentAddress() -> Address? {
        guard let userInfo else {
            if !Constants.isUITest {
                assert(false, "Drive can not work with accounts without emails - they are needed for cryptography")
            }
            Log.error("User info is nil", error: nil, domain: .sessionManagement)
            return nil
        }
        guard let email = userInfo.email else {
            assert(false, "Drive can not work with accounts without emails - they are needed for cryptography")
            Log.error("User info doesn't have an email", error: nil, domain: .sessionManagement)
            return nil
        }
        if email.isEmpty {
            // There was never such check in place, so post a warning, but continue with the address retrieval
            Log.warning("User info email is is empty", domain: .sessionManagement)
        }

        let address = getAddress(for: email)
        if address == nil {
            Log.error("Address not found based on user's email", domain: .sessionManagement, context: LogContext("Number of addresses: \(String(describing: addresses?.count))"))
        }
        return address
    }
    
    public func currentCreator() -> String? {
        self.currentAddress()?.email
    }

    public func getAddress(for email: String) -> Address? {
        let canonicalForm = email.canonicalEmailForm
        return self.addresses?.first(where: { $0.email.canonicalEmailForm == canonicalForm })
    }

    public func getAddress(withId addressId: String) -> Address? {
        return self.addresses?.first(where: { $0.addressID == addressId })
    }

    public func getEmail(addressId: String) -> String? {
        return getAddress(withId: addressId)?.email
    }

    public func getPublicKeys(for email: String) -> [PublicKey] {
        guard let cachedPublicKeys = publicKeys else {
            // fallback for legacy users who logged in before publicKeys caching was introduced
            return getAddress(for: email)?.activePublicKeys ?? []
        }
        let ownKeys = cachedPublicKeys[email.canonicalEmailForm] ?? []
        if !ownKeys.isEmpty {
            return ownKeys
        } else {
            return getForeignPublicKeys(for: email)
        }
    }

    public func getForeignPublicKeys(for email: String) -> [PublicKey] {
        let cachedPublicKeys = foreignPublicKeys ?? [:]
        return cachedPublicKeys[email.canonicalEmailForm] ?? []
    }

    public func getPublicKeys(addressID: String) -> [PublicKey] {
        if let cachedPublicKeys = addressIDPublicKeys {
            return cachedPublicKeys[addressID] ?? []
        } else {
            var keys = [String: [PublicKey]]()
            for address in (addresses ?? []) {
                keys[address.addressID] = address.activePublicKeys
            }
            self.addressIDPublicKeys = keys
            return self.addressIDPublicKeys?[addressID] ?? []
        }
    }

    public func getPublicKeys(email: String, addressID: String) -> [PublicKey] {
        let creatorKeys = getPublicKeys(for: email)
        let addressIDKeys = getPublicKeys(addressID: addressID)
        return creatorKeys + addressIDKeys
    }

    public var allAddresses: [String] {
        allAddressesFullInfo.map(\.email)
    }

    public var allAddressesFullInfo: [Address] {
        addresses ?? []
    }

    public func getAccountInfo() -> AccountInfo? {
        guard let info = self.userInfo else {
            return nil
        }
        let userIdentifier = info.ID
        let email = info.email ?? ""
        let name = info.displayName?.toNilIfEmpty ?? info.name ?? ""
        return .init(userIdentifier: userIdentifier, email: email, displayName: name, accountRecovery: info.accountRecovery)
    }

    public func getUser() -> User? {
        return self.userInfo
    }

    public func getUserInfo() -> UserInfo? {
        guard let info = self.userInfo else {
            return nil
        }

        return UserInfo(
            usedSpace: Double(info.usedDriveSpace ?? info.usedSpace),
            maxSpace: Double(info.maxDriveSpace ?? info.maxSpace),
            invoiceState: InvoiceUserState(rawValue: info.delinquent) ?? .onTime,
            isPaid: info.hasAnySubscription, 
            lockedFlags: info.lockedFlags
        )
    }

    public func getCoreUserInfo() -> ProtonCoreDataModel.UserInfo? {
        guard let user = self.userInfo, let addresses = self.addresses else {
            return nil
        }
        return .init(displayName: user.displayName, hideEmbeddedImages: nil, hideRemoteImages: nil, imageProxy: nil, maxSpace: user.maxSpace, maxBaseSpace: user.maxBaseSpace, maxDriveSpace: user.maxDriveSpace, notificationEmail: nil, signature: nil, usedSpace: user.usedSpace, usedBaseSpace: user.usedBaseSpace, usedDriveSpace: user.usedDriveSpace, userAddresses: addresses, autoSC: nil, language: nil, maxUpload: user.maxUpload, notify: nil, swipeLeft: nil, swipeRight: nil, role: user.role, delinquent: user.delinquent, keys: user.keys, userId: user.ID, sign: nil, attachPublicKey: nil, linkConfirmation: nil, credit: user.credit, currency: user.currency, createTime: user.createTime.map(Int64.init), pwdMode: nil, twoFA: nil, enableFolderColor: nil, inheritParentFolderColor: nil, subscribed: user.subscribed, groupingMode: nil, weekStart: nil, delaySendSeconds: nil, telemetry: nil, crashReports: nil, conversationToolbarActions: nil, messageToolbarActions: nil, listToolbarActions: nil, referralProgram: nil, edmOptOut: nil)
    }
}

extension SessionVault: UploadClientUIDProvider {
    public func getDeviceUUID() -> String {
        guard let deviceUUID else {
            let deviceUUID = UUID().uuidString
            self.deviceUUID = deviceUUID
            return deviceUUID
        }
        return deviceUUID
    }
    
    public func getUploadClientUID() -> String {
        guard let uploadClientUID else {
            guard let user = userInfo else {
                let message = "Upload client UID requested when no userInfo available"
                if !Constants.isUITest {
                    assertionFailure(message)
                }
                Log.error(message, error: nil, domain: .storage)
                return UUID().uuidString
            }
            let rawUID = user.ID + getDeviceUUID()
            let hashedUID = clientPrefix() + rawUID.sha256
            self.uploadClientUID = hashedUID
            return hashedUID
        }

        return uploadClientUID
    }

    private func clientPrefix() -> String {
        #if os(macOS)
        return "macOS_"
        #else
        return "iOS_"
        #endif
    }
}

extension SessionVault: QuotaResource {
    public func getQuota() -> Quota? {
        guard let info = getUserInfo() else {
            return nil
        }
        return Quota(used: Int(info.usedSpace), total: Int(info.maxSpace))
    }

    public var availableQuotaPublisher: AnyPublisher<Quota, Never> {
        self
            .objectWillChange
            .compactMap { [weak self] _ -> Quota? in
                self?.getQuota()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

extension SessionVault: UserInfoResource {
    public var accountInfoPublisher: AnyPublisher<AccountInfo, Never> {
        objectWillChange
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { [weak self] in
                self?.getAccountInfo()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var userInfoPublisher: AnyPublisher<UserInfo, Never> {
        objectWillChange
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { [weak self] in
                self?.getUserInfo()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

public struct AccountInfo: Equatable {
    public let userIdentifier: String
    public let email: String
    public let displayName: String
    public let accountRecovery: AccountRecovery?

    public init(userIdentifier: String, email: String, displayName: String, accountRecovery: AccountRecovery?) {
        self.userIdentifier = userIdentifier
        self.email = email
        self.displayName = displayName
        self.accountRecovery = accountRecovery
    }
}

extension InvoiceUserState: Encodable {}

public struct UserInfo: Equatable, Encodable {
    public let usedSpace: Double
    public let maxSpace: Double
    public let invoiceState: InvoiceUserState
    public let isPaid: Bool
    public let lockedFlags: LockedFlags?

    public init(usedSpace: Double, maxSpace: Double, invoiceState: InvoiceUserState, isPaid: Bool, lockedFlags: LockedFlags? = nil) {
        self.usedSpace = usedSpace
        self.maxSpace = maxSpace
        self.invoiceState = invoiceState
        self.isPaid = isPaid
        self.lockedFlags = lockedFlags
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

    public var isWarning: Bool {
        usedSpace / maxSpace > 0.8
    }

    public var isFull: Bool {
        availableStorage == 0
    }
}

extension SessionVault.Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noRequiredAddressKey: return "Could not find required Address Key locally"
        case .noRequiredPassphrase: return "Could not find required Passphrase locally"
        case .passphrasesVaultEmpty: return "Could not find any Passphrases locally"
        case .addressNotFound: return "Could not find Address for the specified email"
        case .addressHasNoActiveKeys: return "Could not find any active key in the Address"
        case .userNotFound: return "Could not find any User locally"
        case .addressByIDNotFound: return "Could not find address with provided id"
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
