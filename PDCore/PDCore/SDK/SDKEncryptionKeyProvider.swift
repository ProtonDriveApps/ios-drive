// Copyright (c) 2026 Proton AG
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

public final class SDKEncryptionKeyProvider {
    public enum Errors: Error {
        case keyGenerationFailed(status: OSStatus)
    }

    private static let keyByteCount: Int = 32
    private static let keychainKey = "SDKDatabaseEncryptionKey"
    private let keychain: DriveKeychainProtocol

    public init(keychain: DriveKeychainProtocol = DriveKeychain.shared) {
        self.keychain = keychain
    }

    public func getOrCreateEncryptionKey() -> Data? {
        if let existingKey = try? keychain.dataOrError(forKey: Self.keychainKey, attributes: nil),
           existingKey.count == Self.keyByteCount {
            Log.info("Retrieved existing SDK encryption key from keychain", domain: .sdk)
            return existingKey
        }

        var bytes = [UInt8](repeating: 0, count: Self.keyByteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            Log.error("Failed to generate a new SDK encryption key", error: Errors.keyGenerationFailed(status: status), domain: .sdk)
            return nil
        }

        let key = Data(bytes)

        do {
            try keychain.setOrError(key, forKey: Self.keychainKey, attributes: nil)
            Log.info("Generated and stored new SDK encryption key", domain: .sdk)
        } catch {
            Log.error("Failed to store SDK encryption key in keychain", error: error, domain: .sdk)
        }

        return key
    }

    public func removeEncryptionKey() {
        do {
            try keychain.removeOrError(forKey: Self.keychainKey)
            Log.info("Removed SDK encryption key from keychain", domain: .sdk)
        } catch {
            Log.error("Failed to remove SDK encryption key from keychain", error: error, domain: .sdk)
        }
    }
}
