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

import Foundation

extension Invitation {
    public enum InvitationDecryptionError: Error {
        case missingName
        case invalidKeyPacket
        case missingKeyPacketSignature
        case decryptionFailed
    }

    public func decryptedInvitationName() throws -> String {
        let decryptedPassphrase = try memberDecryptedPassphrase(passphrase)
        let clearName = try Decryptor.decryptAttachedTextMessage(name, decryptionKeys: [DecryptionKey(privateKey: shareKey, passphrase: decryptedPassphrase)])
        return clearName
    }

    private func memberDecryptedPassphrase(_ sharePassphrase: String) throws -> String {
        let addressKeys = try getAddressKeys()
        let decryptionKeys = addressKeys.map(\.decryptionKey)
        return try Decryptor.decryptAttachedTextMessage(sharePassphrase, decryptionKeys: decryptionKeys)
    }

    private func getAddressKeys() throws -> [KeyPair] {
        guard let addressKeys = SessionVault.current.getAddress(for: inviteeEmail)?.activeKeys else {
            throw SessionVault.Errors.noRequiredAddressKey
        }
        let keys = addressKeys.compactMap(KeyPair.init)
        return keys
    }

    public func signedSessionKey() throws -> String {
        guard let keyPacket = Data(base64Encoded: keyPacket) else {
            throw DriveError("Invitation has invalid KeyPacket")
        }
        guard let key = try getAddressKeys().map(\.decryptionKey).first else {
            throw DriveError("Could not find propper key for Invitation")
        }
        let sk = try Decryptor.decryptContentKeyPacket(keyPacket, decryptionKey: key)

        let signature = try Encryptor.sign(sk, context: "drive.share-member.member", privateKey: key.privateKey, passphrase: key.passphrase)

        return signature.encodeBase64()
    }
}
func decryptKeyPacket(_ keyPacket: Data, decryptionKey: DecryptionKey) throws -> Data {
    try Decryptor.decryptContentKeyPacket(keyPacket, decryptionKey: decryptionKey)
}
