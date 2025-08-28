// Copyright (c) 2025 Proton AG
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

public typealias NodeWithNodeHashKey = Node & NodeWithNodeHashKeyProtocol

public protocol NodeWithNodeHashKeyProtocol {
    var nodeHashKey: String? { get }
    func decryptNodeHashKey() throws -> String
    func generateHashKey(nodeKey: KeyCredentials) throws -> String
}

public extension NodeWithNodeHashKeyProtocol where Self: Node {
    func decryptNodeHashKey() throws -> String  {
        do {
            let nodePassphrase = try self.decryptPassphrase()
            let decryptionKey = DecryptionKey(privateKey: nodeKey, passphrase: nodePassphrase)

            guard let nodeHashKey = nodeHashKey else {
                throw Errors.invalidFileMetadata
            }
            guard let signatureEmail = signatureEmail else {
                throw Errors.noSignatureAddress
            }

            let addressVerificationKeys = try getAddressPublicKeys(email: signatureEmail)
            let verificationKeys = [nodeKey] + addressVerificationKeys

            let decrypted: VerifiedText
            do {
                decrypted = try Decryptor.decryptAndVerifyNodeHashKey(
                    nodeHashKey,
                    decryptionKeys: [decryptionKey],
                    verificationKeys: verificationKeys
                )
            } catch let error where !(error is Decryptor.Errors) {
                DriveIntegrityErrorMonitor.reportMetadataError(for: self)
                throw error
            }

            switch decrypted {
            case .verified(let nodeHashKey):
                return nodeHashKey

            case .unverified(let nodeHashKey, let error):
                Log.error(error: SignatureError(error, "Folder NodeHashKey", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
                return nodeHashKey
            }

        } catch {
            Log.error(error: DecryptionError(error, "Folder NodeHashKey", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption)
            throw error
        }
    }

    func generateHashKey(nodeKey: KeyCredentials) throws -> String {
        return try Encryptor.generateNodeHashKey(
            nodeKey: nodeKey.key,
            passphrase: nodeKey.passphraseRaw
        )
    }
}
