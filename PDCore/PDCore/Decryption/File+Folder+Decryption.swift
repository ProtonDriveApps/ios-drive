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
import ProtonCoreObservability

#if os(macOS)
public var PDCoreDecryptName: (Node) throws -> String = { try $0.decryptNameWithCryptoGo() }
public var PDCoreDecryptExtendedAttributes: (Revision) throws -> ExtendedAttributes = { try $0.decryptedExtendedAttributesWithCryptoGo() }
#endif

public extension Node {
    enum Errors: Error {
        case noName
        case invalidFileMetadata
        case noAddress
        case noSignatureAddress
    }

    static let unknownNamePlaceholder = String.randomPlaceholder
    
    var decryptedName: String {
        guard let moc = self.moc else {
            return Self.unknownNamePlaceholder
        }
        
        return moc.performAndWait {
            do {
                return try decryptName()
            } catch {
                nameDecryptionFailed = true
                if !self.isFault {
                    self.clearName = Self.unknownNamePlaceholder
                }
                return Self.unknownNamePlaceholder
            }
        }
    }
    
    @objc func decryptName() throws -> String {
        #if os(macOS)
        try PDCoreDecryptName(self)
        #else
        try decryptNameWithCryptoGo()
        #endif
    }

    func decryptNameWithCryptoGo() throws -> String {
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

            let addressID = try getContextShareAddressID()

            let (parentPassphrase, parentKey) = try self.getDirectParentPack()
            let parentNodeKey = DecryptionKey(privateKey: parentKey, passphrase: parentPassphrase)
            let addressKeys = try getAddressPublicKeys(email: signatureEmail, addressID: addressID)
            let verificationKeys = signatureEmail.isEmpty ? [parentKey] : addressKeys
            let decrypted: VerifiedText
            do {
                decrypted = try Decryptor.decryptAndVerifyNodeName(
                    name,
                    decryptionKeys: parentNodeKey,
                    verificationKeys: verificationKeys
                )
            } catch let error where !(error is Decryptor.Errors) {
                DriveIntegrityErrorMonitor.reportMetadataError(for: self)
                throw error
            }

            nameDecryptionFailed = false
            switch decrypted {
            case .verified(let filename):
                self.clearName = filename
                return filename

                // Signature remark: The Name signature is missing before December 2020. Handle appropriately when we display errors.
            case .unverified(let filename, let error):
                Log.error(error: SignatureError(error, "Node Name", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
                self.clearName = filename
                return filename
            }
        } catch {
            Log.error(error: DecryptionError(error, "Node Name", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption)
            throw error
        }
    }

    internal func generateNodeKeys(signersKit: SignersKit) throws -> KeyCredentials {
        let (_, parentKey) = try self.getDirectParentPack()
        let nodeCredentials = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase,
                                                             addressPrivateKey: signersKit.addressKey.privateKey,
                                                             parentKey: parentKey)
        return nodeCredentials
    }
    
    internal func updateNodeKeys(_ nodePassphrase: String, signersKit: SignersKit) throws -> NodeUpdatedCredentials {
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
    
    func encryptName(cleartext name: String, parentKey: String, signersKit: SignersKit) throws -> String {
        return try Encryptor.encryptAndSign(
            name,
            key: parentKey,
            addressPassphrase: signersKit.addressPassphrase,
            addressPrivateKey: signersKit.addressKey.privateKey
        )
    }

    // swiftlint:disable:next function_parameter_count
    func renameNode(
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
            Log.error(error: DecryptionError(error, "Node", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption)
            throw error
        }
    }

    /// BE only needs the new NodePassphrase KeyPacket, the DataPacket and the Signature should not change
    func reencryptNodePassphrase(
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
            Log.error(error: DecryptionError(error, "Node", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption)
            throw error
        }
    }
    
    internal func hashFilename(cleartext name: String) throws -> String {
        guard let parent = self.parentNode else {
            throw Errors.invalidFileMetadata
        }
        let parentNodeHashKey = try parent.decryptNodeHashKey()
        let hash = try Encryptor.hmac(filename: name, parentHashKey: parentNodeHashKey)
        return hash
    }
}

public extension File {
    
    func decryptContentKeyPacket() throws -> Data {
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

            let decrypted: VerifiedBinary
            do {
                decrypted = try Decryptor.decryptAndVerifyContentKeyPacket(
                    contentKeyPacket,
                    decryptionKey: nodeDecryptionKey,
                    signature: contentKeyPacketSignature,
                    verificationKeys: verificationKeys
                )
            } catch let error where !(error is Decryptor.Errors) {
                DriveIntegrityErrorMonitor.reportMetadataError(for: self)
                throw error
            }

            switch decrypted {
            case .verified(let sessionKey):
                return sessionKey

                /*
                 Signature remarks:
                 1) Web is signing the session key while iOS and android were signing the key packet - for old iOS files verification needs to be done on content key as well if session key check fails.
                 2) Previosly the signature was made with the AddressKey but now it's done with the NodeKey
                 */
            case .unverified(let sessionKey, let error):
                Log.error(error: SignatureError(error, "File ContentKeyPacket", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
                return sessionKey
            }
        } catch {
            Log.error(error: DecryptionError(error, "File ContentKeyPacket", description: "LinkID: \(id) \nVolumeID: \(volumeID)"), domain: .encryption)
            throw error
        }
    }

    internal func generateContentKeyPacket(credentials: KeyCredentials, signersKit: SignersKit) throws -> RevisionContentKeys {
        try Encryptor.generateContentKeys(nodeKey: credentials.key, nodePassphrase: credentials.passphraseRaw)
    }

    func reencryptFileName(with newName: String, signersKit: SignersKit) throws  {
        let (_, parentKey) = try getDirectParentPack()
        guard let hashKey = try? parentNode?.decryptNodeHashKey() else {
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
            try? moc.saveOrRollback()
        }
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
