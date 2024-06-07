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

extension Share {
    enum Errors: Error {
        case noPassphrase, noPassphraseSignature
        case noCreator
    }

    internal func generateShareKeys(signersKit: SignersKit) throws -> Encryptor.KeyCredentials {
        let shareKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase,
                                                       addressPrivateKey: signersKit.addressKey.privateKey,
                                                       parentKey: signersKit.addressKey.privateKey)
        return shareKeys
    }

    public func decryptPassphrase() throws -> String {
        do {
            if let cached = self.clearPassphrase {
                return cached
            }

            guard let sharePassphrase = passphrase else {
                throw Errors.noPassphrase
            }

            guard let signature = passphraseSignature else {
                throw Errors.noPassphraseSignature
            }

            let isMigratedShare = try DriveCrypto.keyPacketsCount(in: sharePassphrase) == 2

            if isCollaborativelyShared && isMigratedShare {
                do {
                    return try nodeKeyDecryptedPassphrase(sharePassphrase, signature)
                } catch {
                    Log.error(DecryptionError(error, "Share Passphrase", description: "ShareID: \(id) - Migrated share could not be decrypted 💔"), domain: .encryption)
                    return try memberDecryptedPassphrase(sharePassphrase, signature)
                }
            } else {
                // Main share, Photos share and Devices share and macOS flow (macOS does not have shared by URL)
                return try memberDecryptedPassphrase(sharePassphrase, signature)
            }
        } catch {
            Log.error(DecryptionError(error, "Share Passphrase", description: "ShareID: \(id)"), domain: .encryption)
            throw error
        }
    }

    private func memberDecryptedPassphrase(_ sharePassphrase: String, _ signature: String) throws -> String {
        let addressKeys = try getAddressKeys()
        let verificationKeys = addressKeys.map(\.publicKey)
        let decryptionKeys = addressKeys.map(\.decryptionKey)
        let decrypted = try Decryptor.decryptAndVerifySharePassphrase(
            sharePassphrase,
            armoredSignature: signature,
            verificationKeys: verificationKeys,
            decryptionKeys: decryptionKeys
        )

        switch decrypted {
        case .verified(let clearSharePassphrase):
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase

        case .unverified(let clearSharePassphrase, let error):
            Log.error(SignatureError(error, "Share Passphrase", description: "ShareID: \(id)"), domain: .encryption)
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase
        }
    }

    private func nodeKeyDecryptedPassphrase(_ sharePassphrase: String, _ signature: String) throws -> String {
        let verificationKeys = try getAddressKeys().map(\.publicKey)

        guard let node = root else { throw invalidState("Share should have a root with NodeKey") }
        let nodePassphrase = try node.decryptPassphrase()

        let decrypted = try Decryptor.decryptAndVerifySharePassphrase(
            sharePassphrase,
            armoredSignature: signature,
            verificationKeys: verificationKeys,
            decryptionKeys: [DecryptionKey(privateKey: node.nodeKey, passphrase: nodePassphrase)]
        )

        switch decrypted {
        case .verified(let clearSharePassphrase):
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase

        case .unverified(let clearSharePassphrase, let error):
            Log.error(SignatureError(error, "Share Passphrase", description: "ShareID: \(id)"), domain: .encryption)
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase
        }
    }

    internal func getAddressKeys() throws -> [KeyPair] {
        guard let creator = creator else {
            throw Errors.noCreator
        }
        guard let addressKeys = SessionVault.current.getAddress(for: creator)?.activeKeys else {
            throw SessionVault.Errors.noRequiredAddressKey
        }
        let keys = addressKeys.compactMap(KeyPair.init)
        return keys
    }

    internal func getAddressPublicKeysOfShareCreator() throws -> [PublicKey] {
        guard let creator = creator else {
            throw Errors.noCreator
        }
        return SessionVault.current.getPublicKeys(for: creator)
    }

    internal func getShareCreatorDecryptionKeys() throws -> [DecryptionKey] {
        guard let creator = creator else {
            throw Errors.noCreator
        }
        guard let addressKeys = SessionVault.current.getAddress(for: creator)?.activeKeys else {
            throw SessionVault.Errors.noRequiredAddressKey
        }
        return addressKeys.compactMap(KeyPair.init).map(\.decryptionKey)
    }

}
