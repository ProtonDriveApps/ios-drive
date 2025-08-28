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

extension Node {
    
    func getDirectParentPack() throws -> (parentPassphrase: String, parentKey: String) {
        guard let parentPassphrase = try (self.parentNode?.decryptPassphrase() ?? getMainDirectSharePassphrase()),
              let parentKey = self.parentNode?.nodeKey ?? self.primaryDirectShare?.key else {
                  throw Decryptor.Errors.noParentPacket
              }
        return (parentPassphrase, parentKey)
    }

    private func getMainDirectSharePassphrase() throws -> String? {
        try self.primaryDirectShare?.decryptPassphrase()
    }

    private func getDirectParentSecret() throws -> DecryptionKey {
        let (parentPassphrase, parentKey) = try getDirectParentPack()
        return DecryptionKey(privateKey: parentKey, passphrase: parentPassphrase)
    }

    /// first time will be calculated and later cached in a transient CoreData property
    public func decryptPassphrase() throws -> String {
        do {
            if let cached = self.clearPassphrase {
                return cached
            }

            let decrypted = try decryptNodePassphrase()

            switch decrypted {
            case .verified(let passphrase):
                self.clearPassphrase = passphrase
                return passphrase

            case .unverified(let passphrase, let error):
                Log.error(error: SignatureError(error, "Node", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
                self.clearPassphrase = passphrase
                return passphrase
            }

        } catch {
            Log.error(error: DecryptionError(error, "Node", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption)
            throw error
        }
    }

    internal func decryptNodePassphrase() throws -> VerifiedText {
        let addressKeys = try getAddressPublicKeysOfNodeCreatorWithFallbackToShareCreator()
        let parentNodeKey = try getDirectParentSecret()
        let signatureEmailIsEmpty = signatureEmail?.isEmpty ?? true
        let verificationKeys = signatureEmailIsEmpty ? [parentNodeKey.privateKey] : addressKeys

        let decrypted: VerifiedText
        do {
            decrypted = try Decryptor.decryptAndVerifyNodePassphrase(
                nodePassphrase,
                armoredSignature: nodePassphraseSignature,
                verificationKeys: verificationKeys,
                decryptionKeys: [parentNodeKey]
            )
        } catch let error where !(error is Decryptor.Errors) {
            DriveIntegrityErrorMonitor.reportMetadataError(for: self)
            throw error
        }

        return decrypted
    }

    internal func keyPacket(_ cyphertext: String, newKey: String) throws -> String {
        let (parentPassphrase, parentKey) = try self.getDirectParentPack()
        let sessionKey = try Decryptor.decryptSessionKey(of: cyphertext, privateKey: parentKey, passphrase: parentPassphrase)
        return try Encryptor.encryptSessionKey(sessionKey, withKey: newKey)
    }
}

extension Node {
    
    private func getAddressPublicKeysOfNodeCreatorWithFallbackToShareCreator() throws -> [PublicKey] {
#if os(macOS)
        if let signatureEmail = signatureEmail, let publicKeys = try? getAddressPublicKeys(email: signatureEmail) {
            return publicKeys
        }

        if let share = self.primaryDirectShare {
            return try share.getAddressPublicKeysOfShareCreator()
        }

        throw SessionVault.Errors.noRequiredAddressKey
#else
        let addressID = try getContextShareAddressID()

        if let publicKeys = try? getAddressPublicKeys(email: signatureEmail ?? "", addressID: addressID) {
            return publicKeys
        }

        throw SessionVault.Errors.noRequiredAddressKey
#endif
    }

    internal func getAddressPublicKeys(email: String, addressID: String) throws -> [PublicKey] {
        SessionVault.current.getPublicKeys(email: email, addressID: addressID)
    }

    internal func getAddressPublicKeys(email: String) throws -> [PublicKey] {
        SessionVault.current.getPublicKeys(for: email)
    }
}
