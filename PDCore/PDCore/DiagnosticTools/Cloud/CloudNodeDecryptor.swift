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
import PDClient
import ProtonCoreDataModel

public protocol CloudNodeDecryptor {
    func decryptName(_ node: Link) throws -> String
}

class ConcreteCloudNodeDecryptor: CloudNodeDecryptor {
    typealias Share = PDClient.Share

    private let share: Share

    var addressVerificationKeys = [String: [PublicKey]]() // email: keys - take from addresses
    var addressDecryptionKeys = [String: [DecryptionKey]]() // email: keys - take from addresses

    var passphrases = [Link.LinkID: String]() // linkid: passphrase
    var encryptedPrivateKeys = [Link.LinkID: String]() // linkid: private key

    init(share: PDClient.Share, addresses: [Address], userKeys: [AddressKey], userPassphrases: [String: String]) throws {
        self.share = share
        try consumeAddresses(addresses, userKeys: userKeys, userPassphrases: userPassphrases)
    }

    // fulfill addressPublicKeys, addressDecryptionKeys
    private func consumeAddresses(_ addresses: [Address], userKeys: [AddressKey], userPassphrases: [String: String]) throws {
        for address in addresses {
            var keyPairs = [KeyPair]()

            for addressKey in address.activeKeys {
                assert(!addressKey.publicKey.isEmpty)
                assert(!addressKey.privateKey.isEmpty)

                // Inspired by implementation in SessionVault, not 100% sure
                let userPassphrase = userKeys.compactMap { userKey in
                    userPassphrases[userKey.keyID]
                }.first

                let addressKeyPassphrase = try addressKey._passphrase(userKeys: userKeys, mailboxPassphrase: userPassphrase!)

                let keyPair = KeyPair(
                    publicKey: addressKey.publicKey,
                    privateKey: addressKey.privateKey,
                    passphrase: addressKeyPassphrase
                )
                keyPairs.append(keyPair)
            }

            addressVerificationKeys[address.email] = keyPairs.map(\.publicKey)
            addressDecryptionKeys[address.email] = keyPairs.map(\.decryptionKey)
        }
    }

    // Add parent node passphrase/keys which will later be used to decrypt child attributes
    @discardableResult
    func prepareDecryptionKey(node: Link) throws -> DecryptionKey {
        let parentPrivateKey: String
        let parentPassphrase: String
        let verificationKeys = try getVerificationKeys(for: node)

        // required parent keys
        if let parentLinkID = node.parentLinkID { // folder under root
            parentPrivateKey = encryptedPrivateKeys[parentLinkID]!
            parentPassphrase = passphrases[parentLinkID]!
        } else { // root
            parentPrivateKey = share.key

            let addressDecryptionKeys = addressDecryptionKeys[share.creator]!
            parentPassphrase = try Decryptor.decryptAndVerifySharePassphrase(
                share.passphrase,
                armoredSignature: share.passphraseSignature,
                verificationKeys: verificationKeys,
                decryptionKeys: addressDecryptionKeys
            ).decrypted()
        }

        // parent key used to decrypt node's name and passphrase
        let parentDecryptionKey = DecryptionKey(
            privateKey: parentPrivateKey,
            passphrase: parentPassphrase
        )

        // decrypt and cache passphrase for descendants
        passphrases[node.linkID] = try Decryptor.decryptAndVerifyNodePassphrase(
            node.nodePassphrase,
            armoredSignature: node.nodePassphraseSignature,
            verificationKeys: verificationKeys,
            decryptionKeys: [parentDecryptionKey]
        ).decrypted()
        encryptedPrivateKeys[node.linkID] = node.nodeKey

        return parentDecryptionKey
    }

    func decryptName(_ node: Link) throws -> String {
        encryptedPrivateKeys[node.linkID] = node.nodeKey
        
        // parent key used to decrypt node's name and passphrase
        let parentDecryptionKey = try prepareDecryptionKey(node: node)
        let verificationKeys = try getVerificationKeys(for: node)

        // decrypt and return name
        if node.parentLinkID != nil { // folder under root
            return try Decryptor.decryptAndVerifyNodeName(
                node.name,
                decryptionKeys: parentDecryptionKey,
                verificationKeys: verificationKeys
            ).decrypted()
        } else {
            return "root"
        }
    }

    func getVerificationKeys(for node: Link) throws -> [PublicKey] {
        if let parentLinkID = node.parentLinkID { // folder under root
            return try addressVerificationKeys[node.nameSignatureEmail ?? node.signatureEmail]! ?! "Missing verification key"
        } else { // root
            return try addressVerificationKeys[share.creator] ?! "Missing verification key"
        }
    }
}
