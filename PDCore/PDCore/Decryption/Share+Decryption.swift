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

    internal func generateShareKeys(signersKit: SignersKit) throws -> KeyCredentials {
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
                } catch is MemberDecryptableShareError {
                    return try memberDecryptedPassphrase(sharePassphrase, signature, isCollaborativelyShared: true)
                } catch {
                    Log.error(error: DecryptionError(error, "Share Passphrase", description: "ShareID: \(id) - Migrated share could not be decrypted 💔"), domain: .encryption)
                    return try memberDecryptedPassphrase(sharePassphrase, signature, isCollaborativelyShared: true)
                }
            } else {
                // Main share, Photos share and Devices share and macOS flow (macOS does not have shared by URL)
                return try memberDecryptedPassphrase(sharePassphrase, signature, isCollaborativelyShared: isCollaborativelyShared)
            }
        } catch {
            Log.error(error: DecryptionError(error, "Share Passphrase", description: "ShareID: \(id)"), domain: .encryption)
            throw error
        }
    }

    /// Decryption of Share's passphare using address keys.
    /// For decryption it uses address keys fetched from vault mapped from addressID of a given Share.
    /// Mapping of `addressID` can be found in `getAddressKeys`.
    ///
    /// - Parameters:
    ///   - sharePassphrase: Encrypted passhprase of `Share` entity.
    ///   - signature: Passhprase signature of `Share` entity.
    ///   - isCollaborativelyShared: True marks a collaboratively shared item, additional verification (mapped by inviter's email) keys will be used for verification.
    /// - Returns: Decrypted passphrase.
    /// - Throws: An error if decryption fails. Doesn't throw when verification fails.
    private func memberDecryptedPassphrase(_ sharePassphrase: String, _ signature: String, isCollaborativelyShared: Bool) throws -> String {
        let addressKeys = try getAddressKeys()
        var verificationKeys = addressKeys.map(\.publicKey)
        if isCollaborativelyShared, let inviterEmail = members.first?.inviter {
            verificationKeys += SessionVault.current.getForeignPublicKeys(for: inviterEmail)
        }
        let decryptionKeys = addressKeys.map(\.decryptionKey)
        let decrypted: VerifiedText
        do {
            decrypted = try Decryptor.decryptAndVerifySharePassphrase(
                sharePassphrase,
                armoredSignature: signature,
                verificationKeys: verificationKeys,
                decryptionKeys: decryptionKeys
            )
        } catch let error where !(error is Decryptor.Errors) {
            DriveIntegrityErrorMonitor.reportError(for: self)
            throw error
        }

        switch decrypted {
        case .verified(let clearSharePassphrase):
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase

        case .unverified(let clearSharePassphrase, let error):
            Log.error(error: SignatureError(error, "Share Passphrase", description: "ShareID: \(id)"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase
        }
    }

    /// Decryption of Share's passphare using root node's keys.
    /// For decryption it uses address keys fetched from vault mapped from addressID of a given Share.
    /// Mapping of `addressID` can be found in `getAddressKeys`.
    /// This function is used within collaborative sharing context (shared with me items), so will try to verify
    /// using inviter's email's keys.
    ///
    /// - Parameters:
    ///   - sharePassphrase: Encrypted passhprase of `Share` entity.
    ///   - signature: Passhprase signature of `Share` entity.
    /// - Returns: Decrypted passphrase.
    /// - Throws: An error if decryption fails. Doesn't throw when verification fails.
    private func nodeKeyDecryptedPassphrase(_ sharePassphrase: String, _ signature: String) throws -> String {
        var verificationKeys = try getAddressKeys().map(\.publicKey)
        if let inviterEmail = members.first?.inviter {
            verificationKeys += SessionVault.current.getForeignPublicKeys(for: inviterEmail)
        }

        guard let node = root else { throw invalidState("Share should have a root with NodeKey") }
        guard node.parentNode != nil else { throw MemberDecryptableShareError() }
        let nodePassphrase = try node.decryptPassphrase()

        let decrypted: VerifiedText
        do {
            decrypted = try Decryptor.decryptAndVerifySharePassphrase(
                sharePassphrase,
                armoredSignature: signature,
                verificationKeys: verificationKeys,
                decryptionKeys: [DecryptionKey(privateKey: node.nodeKey, passphrase: nodePassphrase)]
            )
        } catch let error where !(error is Decryptor.Errors) {
            DriveIntegrityErrorMonitor.reportError(for: self)
           throw error
       }

        switch decrypted {
        case .verified(let clearSharePassphrase):
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase

        case .unverified(let clearSharePassphrase, let error):
            Log.error(error: SignatureError(error, "Share Passphrase", description: "ShareID: \(id)"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
            self.clearPassphrase = clearSharePassphrase
            return clearSharePassphrase
        }
    }

    struct MemberDecryptableShareError: Error { }

    internal func getAddressKeys() throws -> [KeyPair] {
        guard let addressID = try? getAddressID() else { // addressID is deprecated for SharedWithMe items, we should get it from memberships.
            throw SessionVault.Errors.noRequiredAddressKey
        }

        if addressID.isEmpty {
            Log.error("Share's addressID is empty", error: nil, domain: .metadata)
        }
        if let addressKeys = SessionVault.current.getAddress(withId: addressID)?.activeKeys {
            if addressKeys.isEmpty {
                Log.error("Address by addressID contains empty active keys", error: nil, domain: .sessionManagement)
            }
            let keys = addressKeys.compactMap(KeyPair.init)
            if !addressKeys.isEmpty && keys.isEmpty {
                Log.error("Unable to map address (fetched by addressID) keys to valid key pairs", error: nil, domain: .sessionManagement)
            }
            return keys
        }

        // We used to fallback to `creator`. This is very much deprecated and we should never use that attribute 'except in a UI display as "creator"'
        throw SessionVault.Errors.noRequiredAddressKey
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
