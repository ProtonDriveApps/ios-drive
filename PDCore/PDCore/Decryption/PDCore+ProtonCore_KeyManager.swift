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
import ProtonCoreDataModel
import ProtonCoreKeyManager

public typealias DecryptionKey = ProtonCoreKeyManager.DecryptionKey

public struct KeyPair: Equatable {
    let publicKey: ArmoredKey
    let privateKey: ArmoredKey
    let passphrase: ArmoredKey
}

extension KeyPair {
    public var decryptionKey: DecryptionKey {
        .init(privateKey: privateKey, passphrase: passphrase)
    }
}

extension KeyPair {
    public init?(addressKey: AddressManager.AddressKey) {
        do {
            self.publicKey = try addressKey.publicKey()
            self.privateKey = addressKey.privateKey
            self.passphrase = try SessionVault.current.addressPassphrase(for: addressKey)
        } catch {
            Log.error("Initialize KeyPair failed", error: error, domain: .sessionManagement)
            return nil
        }
    }
}

extension Key {
    func publicKey() throws -> String {
        guard case let publicKey = self.publicKey, !publicKey.isEmpty else {
            throw NSError(domain: "Could not obtain valid CryptoKey from AddressKey", code: 0)
        }
        return publicKey
    }
}

extension Address {
    public var activeKeys: [Key] {
        keys.filter { $0.active == 1 }
    }
    
    var activePublicKeys: [PublicKey] {
        activeKeys.map(\.publicKey)
    }
}
