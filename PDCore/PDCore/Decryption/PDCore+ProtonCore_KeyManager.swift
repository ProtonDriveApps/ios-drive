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

import ProtonCore_DataModel
import ProtonCore_KeyManager

typealias DecryptionKey = ProtonCore_KeyManager.DecryptionKey

struct KeyPair: Equatable {
    let publicKey: ArmoredKey
    let privateKey: ArmoredKey
    let passphrase: ArmoredKey
}

extension KeyPair {
    var decryptionKey: DecryptionKey {
        .init(privateKey: privateKey, passphrase: passphrase)
    }
}

extension KeyPair {
    init?(addressKey: AddressManager.AddressKey) {
        guard let publicKey = try? addressKey.publicKey(),
              let passphrase = try? SessionVault.current.addressPassphrase(for: addressKey) else {
            return nil
        }
        self.publicKey = publicKey
        self.privateKey = addressKey.privateKey
        self.passphrase = passphrase
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
    var activeKeys: [Key] {
        keys.filter { $0.active == 1 }
    }
    
    var activePublicKeys: [PublicKey] {
        activeKeys.map(\.publicKey)
    }
}
