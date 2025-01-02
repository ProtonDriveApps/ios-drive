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

class SecureStore<T: Codable> {
    internal weak var keyProvider: MainKeyProvider?
    private let label: String
    private let keychain: DriveKeychainProtocol
    
    internal init(label: String, keychain: DriveKeychainProtocol = KeychainProvider.shared.keychain) {
        self.label = label
        self.keychain = keychain
    }
    
    internal func hasCyphertext() -> Bool {
        let data = try? keychain.dataOrError(forKey: label, attributes: nil)
        return data != nil
    }
    
    internal func update(_ newValue: T) throws {
        guard let keyProvider else { return }
        guard let key = try keyProvider.mainKeyOrError else { return }
        
        let data = try JSONEncoder().encode(newValue)
        let locked = try Locked<Data>(clearValue: data, with: key)
        let cypherdata = locked.encryptedValue
        
        try keychain.setOrError(cypherdata, forKey: label, attributes: nil)
    }
    
    internal func retrieve() throws -> T? {
        guard let keyProvider else { return nil } 
        guard let key = try keyProvider.mainKeyOrError else { return nil }
        
        // Read value from Keychain
        guard let cypherdata = try keychain.dataOrError(forKey: label, attributes: nil) else { return nil }
        
        let locked = Locked<Data>(encryptedValue: cypherdata)
        let data = try locked.unlock(with: key)

        // Convert data to the desire data type
        let value = try JSONDecoder().decode(T.self, from: data)
        return value
    }
    
    internal func wipe() throws {
        try keychain.removeOrError(forKey: label)
    }
    
    internal func duplicate(to newLabel: String) throws {
        guard let cypherdata = try keychain.dataOrError(forKey: label, attributes: nil) else {
            try keychain.removeOrError(forKey: newLabel)
            return
        }
        try keychain.setOrError(cypherdata, forKey: newLabel, attributes: nil)
    }
}
