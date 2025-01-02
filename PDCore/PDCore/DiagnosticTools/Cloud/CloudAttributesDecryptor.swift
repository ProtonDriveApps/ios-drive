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

public protocol CloudAttributesDecryptor: CloudNodeDecryptor {
    func buildDecryptionData(_ node: PDClient.Link) throws
    func decryptExtendedAttributes(_ node: Link) throws -> ExtendedAttributes
}

final class ConcreteCloudAttributesDecryptor: ConcreteCloudNodeDecryptor, CloudAttributesDecryptor {
    func buildDecryptionData(_ node: PDClient.Link) throws {
        // Need to store node's decryption data to allow further usage later
        // No need to return anything
        try prepareDecryptionKey(node: node)
    }

    func decryptExtendedAttributes(_ node: Link) throws -> ExtendedAttributes {
        // parent key used to decrypt node's passphrase
        let parentDecryptionKey = try getParentKey(for: node)
        let verificationKeys = try getVerificationKeys(for: node)

        let decryptedPassphrase = try Decryptor.decryptAndVerifyNodePassphrase(
            node.nodePassphrase,
            armoredSignature: node.nodePassphraseSignature,
            verificationKeys: [node.nodeKey] + verificationKeys,
            decryptionKeys: [parentDecryptionKey]
        ).decrypted()

        // node key used to decrypt node's x attributes
        let decryptionKey = DecryptionKey(
            privateKey: node.nodeKey,
            passphrase: decryptedPassphrase
        )

        let extendedAttributesString = try Decryptor.decryptAndVerifyXAttributes(
            node.XAttr ?? "",
            decryptionKey: decryptionKey,
            verificationKeys: verificationKeys
        ).decrypted()
        return try JSONDecoder().decode(ExtendedAttributes.self, from: extendedAttributesString)
    }

    private func getParentKey(for node: Link) throws -> DecryptionKey {
        // required parent key
        let parentLinkID = try node.parentLinkID ?! "Missing parentLinkID"
        let parentPrivateKey = try encryptedPrivateKeys[parentLinkID] ?! "Missing private key"
        let parentPassphrase = try passphrases[parentLinkID] ?! "Missing parent passphrase"

        // parent key used to decrypt node's attributes
        return DecryptionKey(
            privateKey: parentPrivateKey,
            passphrase: parentPassphrase
        )
    }
}
