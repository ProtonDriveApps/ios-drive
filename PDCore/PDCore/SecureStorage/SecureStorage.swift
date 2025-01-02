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
import ProtonCoreKeymaker

@propertyWrapper
public final class SecureStorage<T: Codable> {
    internal let label: String
    private let persistentStore: SecureStore<T>
    private let inMemoryStore: InMemoryStore<T>?
    private var crossProcessNotifier: CrossProcessNotifier?
    
    private var wasConfigured = false
    
    private let allowedKeychainWriteErrorCodes: Set<OSStatus>

    /// - Parameters:
    ///   - label: This label will be used for persistent store and cross-process notifications
    ///   - caching: whether in-memory store chaching is needed. In-memory store allows faster access when multiple subsequent calls are made (like during decryption of filenames for folder children), but is not secure against memory dump attack.
    public init(label: String, caching: Bool = false, allowedKeychainWriteErrorCodes: Set<OSStatus> = []) {
        self.label = label
        self.inMemoryStore = caching ? InMemoryStore() : nil
        self.persistentStore = SecureStore(label: label, keychain: KeychainProvider.shared.keychain)
        self.allowedKeychainWriteErrorCodes = allowedKeychainWriteErrorCodes
    }

    /// Every secure storage is required to call this method early in its lifecycle: this is a point of dependency injection, because constructor of @propertyWrapper is not suited for that.
    ///
    /// - Parameters:
    ///   - keyProvider: MainKey provider that would be used to protect information in persistent storage.
    ///   - notifying: whether Darwin notificatrion should be sent upon saving or listened to
    ///   - logger: Logger object
    public func configure(with keyProvider: MainKeyProvider, notifying: Bool = false) {
        self.wasConfigured = true
        self.persistentStore.keyProvider = keyProvider
        
        self.crossProcessNotifier = notifying ? CrossProcessNotifier(
            notificationCenter: .shared,
            label: String(describing: Self.self) + "." + label,
            onReceive: { [inMemoryStore] _ in
                inMemoryStore?.wipe()
            }
        ) : nil
    }
    
    public func hasCyphertext() -> Bool {
        persistentStore.hasCyphertext()
    }

    public var wrappedValue: T? {
        get {
            assert(wasConfigured, "Attempt to use unconfigured " + String(describing: Self.self))
            
            if let cachedValue = inMemoryStore?.retrieve() {
                return cachedValue
            }

            do {
                let value = try persistentStore.retrieve()
                inMemoryStore?.update(value)
                return value
            } catch {
                do {
                    if let keychainAccessError = error as? Keychain.AccessError {
                        Log.error(keychainAccessError, domain: .storage)
                        fatalError("Crashing because of keychain access error \(keychainAccessError.localizedDescription)")
                    } else {
                        try persistentStore.wipe()
                        Log.info("wiped persistent store \(label) because of: \(error.localizedDescription)", domain: .storage)
                    }
                    return nil
                } catch {
                    Log.error("has not wiped persistent store \(label) failed because of: \(error.localizedDescription)", domain: .storage)
                    return nil
                }
            }
        }
        
        set {
            do {
                assert(wasConfigured, "Attempt to use unconfigured " + String(describing: Self.self))
            
                guard let newValue = newValue else {
                    return try wipeValue()
                }
            
                try persistentStore.update(newValue)
                inMemoryStore?.update(newValue)
                crossProcessNotifier?.post() // Notify other processes that persistent store was updated
            } catch {
                if let keychainAccessError = error as? Keychain.AccessError {
                    switch keychainAccessError {
                    case .updateFailed(_, let status) where allowedKeychainWriteErrorCodes.contains(status),
                         .writeFailed(_, let status) where allowedKeychainWriteErrorCodes.contains(status):
                        Log.info("Allowing error \(keychainAccessError.localizedDescription)",
                                 domain: .storage, sendToSentryIfPossible: true)
                        inMemoryStore?.update(newValue)
                        crossProcessNotifier?.post()
                    default:
                        Log.error(keychainAccessError, domain: .storage)
                        fatalError("Crashing because of keychain access error \(keychainAccessError.localizedDescription)")
                    }
                } else {
                    Log.error(error, domain: .storage)
                    assert(false, "Failed to lock secured storage: " + error.localizedDescription)
                    inMemoryStore?.wipe()
                }
            }
        }
    }

    public func wipeValue() throws {
        Log.info("wiping persistent store \(label) in wipeValue()", domain: .storage)
        try persistentStore.wipe()
        inMemoryStore?.wipe()
    }
    
    public func duplicate(to newLabel: String, andNotify notify: Bool = false) throws {
        try persistentStore.duplicate(to: newLabel)
        
        if notify {
            CrossProcessNotifier(
                notificationCenter: .shared,
                label: String(describing: Self.self) + "." + newLabel,
                onReceive: { _ in }
            ).post()
        }
    }
}
