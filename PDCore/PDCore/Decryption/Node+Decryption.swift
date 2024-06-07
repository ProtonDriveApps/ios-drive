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
        guard let parentPassphrase = try (self.parentLink?.decryptPassphrase() ?? getMainDirectSharePassphrase()),
              let parentKey = self.parentLink?.nodeKey ?? self.primaryDirectShare?.key else {
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
                Log.error(SignatureError(error, "Node", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
                self.clearPassphrase = passphrase
                return passphrase
            }

        } catch {
            Log.error(DecryptionError(error, "Node", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
            throw error
        }
    }

    internal func decryptNodePassphrase() throws -> VerifiedText {
        let addressKeys = try getAddressPublicKeysOfNodeCreatorWithFallbackToShareCreator()
        let parentNodeKey = try getDirectParentSecret()

        let decrypted = try Decryptor.decryptAndVerifyNodePassphrase(
            nodePassphrase,
            armoredSignature: nodePassphraseSignature,
            verificationKeys: addressKeys,
            decryptionKeys: [parentNodeKey]
        )

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
        if let signatureEmail = signatureEmail, let publicKeys = try? getAddressPublicKeys(email: signatureEmail) {
            return publicKeys
        }
        
        if let share = self.primaryDirectShare {
            return try share.getAddressPublicKeysOfShareCreator()
        }

        throw SessionVault.Errors.noRequiredAddressKey
    }

    internal func getAddressPublicKeys(email: String) throws -> [PublicKey] {
        SessionVault.current.getPublicKeys(for: email)
    }
    
}
