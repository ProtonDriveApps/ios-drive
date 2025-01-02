// Copyright (c) 2024 Proton AG
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

import CryptoKit
import Foundation

struct AESGCMEncryptionResult {
    let encryptedData: Data
    let key: Data
}

protocol AESGCMEncryptionResource {
    /// Encrypts using 32 bytes symmetric key, 16 bytes generated initialization vector
    /// Result is `[iv]ciphertext[tag]`
    func encrypt(data: Data) throws -> AESGCMEncryptionResult
}

final class CryptoKitAESGCMEncryptionResource: AESGCMEncryptionResource {
    func encrypt(data: Data) throws -> AESGCMEncryptionResult {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes {
            return Data(Array($0))
        }
        let ivKey = SymmetricKey(size: .bits128)
        let ivData = ivKey.withUnsafeBytes {
            return Data(Array($0))
        }
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: ivData))
        let encryptedData = ivData + sealedBox.ciphertext + sealedBox.tag
        return AESGCMEncryptionResult(encryptedData: encryptedData, key: keyData)
    }
}
