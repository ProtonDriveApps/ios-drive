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

public extension Node {
    enum Errors: Error {
        case noName
        case invalidFileMetadata
        case noAddress
        case noSignatureAddress
    }

    private static let unknownNamePlaceholder = String.randomPlaceholder
    
    var decryptedName: String {
        guard let moc = self.moc else {
            return Self.unknownNamePlaceholder
        }
        
        return moc.performAndWait {
            do {
                return try decryptName()
            } catch {
                if !self.isFault {
                    self.clearName = Self.unknownNamePlaceholder
                }
                return Self.unknownNamePlaceholder
            }
        }
    }

    func decryptName() throws -> String {
        do {
            if !Constants.runningInExtension {
                // Looks like file providers do no exchange updates across contexts properly
                if let cached = self.clearName {
                    return cached
                }

                // Node can be a fault on in the file providers at this point
                guard !isFault else { return Self.unknownNamePlaceholder }
            }

            guard let name = self.name else {
                throw Errors.noName
            }
            guard let signatureEmail = nameSignatureEmail ?? signatureEmail else {
                throw Errors.noSignatureAddress
            }
            let (parentPassphrase, parentKey) = try self.getDirectParentPack()
            let parentNodeKey = DecryptionKey(privateKey: parentKey, passphrase: parentPassphrase)
            let addressKeys = try getAddressPublicKeys(email: signatureEmail)
            let decrypted = try Decryptor.decryptAndVerifyNodeName(
                name,
                decryptionKeys: parentNodeKey,
                verificationKeys: addressKeys
            )

            switch decrypted {
            case .verified(let filename):
                self.clearName = filename
                return filename

                // Signature remark: The Name signature is missing before December 2020. Handle appropriately when we display errors.
            case .unverified(let filename, let error):
                Log.error(SignatureError(error, "Node Name", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
                self.clearName = filename
                return filename
            }

        } catch {
            Log.error(DecryptionError(error, "Node Name", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
            throw error
        }
    }

    internal func generateNodeKeys(signersKit: SignersKit) throws -> Encryptor.KeyCredentials {
        let (_, parentKey) = try self.getDirectParentPack()
        let nodeCredentials = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase,
                                                             addressPrivateKey: signersKit.addressKey.privateKey,
                                                             parentKey: parentKey)
        return nodeCredentials
    }
    
    internal func updateNodeKeys(_ nodePassphrase: String, signersKit: SignersKit) throws -> Encryptor.NodeUpdatedCredentials {
        let (_, parentKey) = try self.getDirectParentPack()
        let credentials = try Encryptor.updateNodeKeys(passphraseString: nodePassphrase,
                                                       addressPassphrase: signersKit.addressPassphrase,
                                                       addressPrivateKey: signersKit.addressKey.privateKey,
                                                       parentKey: parentKey)
        return credentials
    }
    
    internal func encryptName(cleartext name: String, signersKit: SignersKit) throws -> String {
        let encryptedName: String = try managedObjectContext!.performAndWait {
            let (_, parentKey) = try self.getDirectParentPack()
            return try Encryptor.encryptAndSign(name, key: parentKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
        }
        return encryptedName
    }

    // swiftlint:disable:next function_parameter_count
    internal func renameNode(
        oldEncryptedName: String,
        oldParentKey: String,
        oldParentPassphrase: String,
        newClearName: String,
        newParentKey: String,
        signersKit: SignersKit
    ) throws -> String {
        let splitMessage = try Encryptor.splitPGPMessage(oldEncryptedName)

        let decKeyRing = try Decryptor.buildPrivateKeyRing(decryptionKeys: [.init(privateKey: oldParentKey, passphrase: oldParentPassphrase)])
        let sessionKey = try execute { try decKeyRing.decryptSessionKey(splitMessage.keyPacket) }

        let encKeyRing = try Decryptor.buildPublicKeyRing(armoredKeys: [newParentKey])

        let signingKeyRing = try Decryptor.buildPrivateKeyRing(decryptionKeys: [signersKit.signingKey])
        let message = try Encryptor.encryptAndSign(newClearName, using: sessionKey, encryptingKeyRing: encKeyRing, signingKeyRing: signingKeyRing)

        return try executeAndUnwrap { message.getArmored(&$0) }
    }

    internal func reencryptNodeNameKeyPacket(
        oldEncryptedName: String,
        oldParentKey: String,
        oldParentPassphrase: String,
        newParentKey: String
    ) throws -> String {
        do {
            return try Encryptor.reencryptKeyPacket(
                of: oldEncryptedName,
                oldParentKey: oldParentKey,
                oldParentPassphrase: oldParentPassphrase,
                newParentKey: newParentKey
            )
        } catch {
            Log.error(DecryptionError(error, "Node", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
            throw error
        }
    }

    /// BE only needs the new NodePassphrase KeyPacket, the DataPacket and the Signature should not change
    internal func reencryptNodePassphrase(
        oldNodePassphrase: String,
        oldParentKey: String,
        oldParentPassphrase: String,
        newParentKey: String
    ) throws -> Armored {
        do {
            return try Encryptor.reencryptKeyPacket(
                of: oldNodePassphrase,
                oldParentKey: oldParentKey,
                oldParentPassphrase: oldParentPassphrase,
                newParentKey: newParentKey
            )
        } catch {
            Log.error(DecryptionError(error, "Node", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
            throw error
        }
    }
    
    internal func hashFilename(cleartext name: String) throws -> String {
        guard let parent = self.parentLink else {
            throw Errors.invalidFileMetadata
        }
        let parentNodeHashKey = try parent.decryptNodeHashKey()
        let hash = try Encryptor.hmac(filename: name, parentHashKey: parentNodeHashKey)
        return hash
    }
}

public extension File {
    
    internal func decryptContentKeyPacket() throws -> Data {
        do {
            guard let base64EncodedContentKeyPacket = contentKeyPacket,
                  let contentKeyPacket = Data(base64Encoded: base64EncodedContentKeyPacket) else {
                throw Errors.invalidFileMetadata
            }
            guard let signatureEmail = signatureEmail else {
                throw Errors.noSignatureAddress
            }
            let creatorAddresKeys = try getAddressPublicKeys(email: signatureEmail)
            let nodePassphrase = try decryptPassphrase()
            let nodeDecryptionKey = DecryptionKey(privateKey: nodeKey, passphrase: nodePassphrase)
            let verificationKeys = [nodeKey] + creatorAddresKeys

            let decrypted = try Decryptor.decryptAndVerifyContentKeyPacket(
                contentKeyPacket,
                decryptionKey: nodeDecryptionKey,
                signature: contentKeyPacketSignature,
                verificationKeys: verificationKeys
            )

            switch decrypted {
            case .verified(let sessionKey):
                return sessionKey

                /*
                 Signature remarks:
                 1) Web is signing the session key while iOS and android were signing the key packet - for old iOS files verification needs to be done on content key as well if session key check fails.
                 2) Previosly the signature was made with the AddressKey but now it's done with the NodeKey
                 */
            case .unverified(let sessionKey, let error):
                Log.error(SignatureError(error, "File ContentKeyPacket", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
                return sessionKey
            }
        } catch {
            Log.error(DecryptionError(error, "File ContentKeyPacket", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
            throw error
        }
    }

    internal func generateContentKeyPacket(credentials: Encryptor.KeyCredentials, signersKit: SignersKit) throws -> RevisionContentKeys {
        try Encryptor.generateContentKeys(nodeKey: credentials.key, nodePassphrase: credentials.passphraseRaw)
    }

    func reencryptFileName(with newName: String, signersKit: SignersKit) throws  {
        let (_, parentKey) = try getDirectParentPack()
        guard let hashKey = try? parentLink?.decryptNodeHashKey() else {
            throw NSError(domain: "Encryption", code: 1)
        }
        let newHash = try Encryptor.hmac(filename: newName, parentHashKey: hashKey)
        guard let moc = self.moc else {
            throw Device.noMOC()
        }
        try moc.performAndWait {
            let encryptedName = try Encryptor.encryptAndSign(newName, key: parentKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
            name = encryptedName
            nodeHash = newHash
            try? moc.saveWithParentLinkCheck()
        }
    }

}

public extension Folder {
    
    internal func decryptNodeHashKey() throws -> String  {
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

            let decrypted = try Decryptor.decryptAndVerifyNodeHashKey(
                nodeHashKey,
                decryptionKeys: [decryptionKey],
                verificationKeys: verificationKeys
            )

            switch decrypted {
            case .verified(let nodeHashKey):
                return nodeHashKey

            case .unverified(let nodeHashKey, let error):
                Log.error(SignatureError(error, "Folder NodeHashKey", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
                return nodeHashKey
            }

        } catch {
            Log.error(DecryptionError(error, "Folder NodeHashKey", description: "LinkID: \(id) \nShareID: \(shareID)"), domain: .encryption)
            throw error
        }
    }

    internal func generateHashKey(nodeKey: Encryptor.KeyCredentials) throws -> String {
        let hashKey = try Encryptor.generateNodeHashKey(
            nodeKey: nodeKey.key,
            passphrase: nodeKey.passphraseRaw
        )
        return hashKey
    }
}

extension SignersKit {
    typealias SigningKey = DecryptionKey

    var signingKey: SigningKey {
        SigningKey(privateKey: addressKey.privateKey, passphrase: addressPassphrase)
    }
}

public extension String {
    static var randomPlaceholder: String {
        var chars = Array(repeating: "☒", count: Int.random(in: 8..<15))
        for _ in 0 ..< Int.random(in: 0..<4) {
            chars.insert(" ", at: Int.random(in: 0 ..< chars.count))
        }
        return chars.joined()
    }
}
