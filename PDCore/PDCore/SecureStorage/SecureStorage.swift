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

@propertyWrapper
final class SecureStorage<T: Codable> {
    private let label: String
    private let persistentStore: SecureStore<T>
    private let inMemoryStore: InMemoryStore<T>?
    private var logger: LogObject.Type?
    private var crossProcessNotifier: CrossProcessNotifier?
    
    private var wasConfigured = false

    /// - Parameters:
    ///   - label: This label will be used for persistent store and cross-process notifications
    ///   - caching: whether in-memory store chaching is needed. In-memory store allows faster access when multiple subsequent calls are made (like during decryption of filenames for folder children), but is not secure against memory dump attack.
    internal init(label: String, caching: Bool = false) {
        self.label = label
        self.inMemoryStore = caching ? InMemoryStore() : nil
        self.persistentStore = SecureStore(label: label)
    }

    /// Every secure storage is required to call this method early in its lifecycle: this is a point of dependency injection, because constructor of @propertyWrapper is not suited for that.
    ///
    /// - Parameters:
    ///   - keyProvider: MainKey provider that would be used to protect information in persistent storage.
    ///   - notifying: whether Darwin notificatrion should be sent upon saving or listened to
    ///   - logger: Logger object
    internal func configure(with keyProvider: MainKeyProvider, notifying: Bool = false, logger: LogObject.Type? = nil) {
        self.wasConfigured = true
        self.persistentStore.keyProvider = keyProvider
        self.logger = logger
        
        self.crossProcessNotifier = notifying ? CrossProcessNotifier(
            notificationCenter: .shared,
            label: String(describing: Self.self) + "." + label,
            onReceive: { [inMemoryStore] _ in
                inMemoryStore?.wipe()
            }
        ) : nil
    }
    
    internal func hasCyphertext() -> Bool {
        persistentStore.hasCyphertext()
    }

    var wrappedValue: T? {
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
                if let logger = logger {
                    ConsoleLogger.shared?.log(error, osLogType: logger)
                }
                persistentStore.wipe()
                return nil
            }
        }
        
        set {
            assert(wasConfigured, "Attempt to use unconfigured " + String(describing: Self.self))
            
            guard let newValue = newValue else {
                return wipeValue()
            }
            
            do {
                try persistentStore.update(newValue)
                inMemoryStore?.update(newValue)
                crossProcessNotifier?.post() // Notify other processes that persistent store was updated
            } catch {
                if let logger = logger {
                    ConsoleLogger.shared?.log(error, osLogType: logger)
                }
                assert(false, "Failed to lock secured storage: " + error.localizedDescription)
                inMemoryStore?.wipe()
            }
        }
    }

    func wipeValue() {
        persistentStore.wipe()
        inMemoryStore?.wipe()
    }
}
