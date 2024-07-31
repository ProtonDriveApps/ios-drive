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

extension ShareURL {
    struct ShareURLError: Error {
        let message: String
    }

    public func decryptPassword() throws -> String {
        do {
            if let cached = self.clearPassword {
                return cached
            }

            let keys = try getAddressKeys()
            let decryptionKeys = keys.map(\.decryptionKey)

            let clearPassword = try Decryptor.decrypt(decryptionKeys: decryptionKeys, value: password)
            self.clearPassword = clearPassword

            return clearPassword
        } catch {
            Log.error(DecryptionError(error, "ShareURL - (initial)", description: "ShareURLID: \(id), ShareID: \(share.id)"), domain: .encryption)
            do {
                let keys = try getAllKeys()
                let decryptionKeys = keys.map(\.decryptionKey)

                let clearPassword = try Decryptor.decrypt(decryptionKeys: decryptionKeys, value: password)
                self.clearPassword = clearPassword

                return clearPassword
            } catch {
                Log.error(DecryptionError(error, "ShareURL", description: "ShareURLID: \(id), ShareID: \(share.id)"), domain: .encryption)
                throw error
            }
        }
    }

    private func getAllKeys() throws -> [KeyPair] {
        guard let addressKeys = SessionVault.current.addresses?.compactMap({ $0 }).flatMap(\.activeKeys) else {
            throw SessionVault.Errors.noRequiredAddressKey
        }

        return addressKeys.compactMap(KeyPair.init)
    }

    private func getAddressKeys() throws -> [KeyPair] {
        guard let addressKeys = SessionVault.current.getAddress(for: creatorEmail)?.activeKeys else {
            throw SessionVault.Errors.noRequiredAddressKey
        }

        let keys = addressKeys.compactMap(KeyPair.init)

        return keys
    }
}
