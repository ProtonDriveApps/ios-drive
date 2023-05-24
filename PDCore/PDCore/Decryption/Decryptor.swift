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
import GoLibs
import ProtonCore_KeyManager
import ProtonCore_Authentication
import ProtonCore_DataModel
import CommonCrypto

/// ProtonCore_KeyManager framework provides a number of static methods - high-level API to work with Crypto.xcframework
/// This class gives us space to override that functional
class Decryptor {
    
    typealias CoreDecryptor = ProtonCore_KeyManager.Decryptor
    typealias Errors = CoreDecryptor.Errors
    
    /*
     Decrypt ShareURL password (not signed) -> Does not need verification
     Decrypt Node's name -> Needs to be verified
     */
    static func decrypt(decryptionKeys: [DecryptionKey], value: String) throws -> String {
        try CoreDecryptor.decrypt(decryptionKeys: decryptionKeys, value: value)
    }

    static func decryptSessionKey(of cyphertext: String,
                                  privateKey: String,
                                  passphrase: String) throws -> CryptoSessionKey {
        try CoreDecryptor.decryptSessionKey(of: cyphertext, privateKey: privateKey, passphrase: passphrase)
    }
}

extension Decryptor {

    static func decryptAndVerifySharePassphrase(
        _ armoredPassphrase: ArmoredMessage,
        armoredSignature: ArmoredSignature,
        verificationKeys: [ArmoredKey],
        decryptionKeys: [DecryptionKey]
    ) throws -> VerifiedText {
        try decryptAndVerifyDetachedTextMessage(armoredPassphrase, armoredSignature, decryptionKeys, verificationKeys)
    }

    static func decryptAndVerifyNodeName(
        _ armoredName: ArmoredMessage,
        decryptionKeys: DecryptionKey,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedText {
        try decryptAndVerifyAttachedTextMessage(armoredName, decryptionKeys: [decryptionKeys], verificationKeys: verificationKeys)
    }

    static func decryptAndVerifyNodePassphrase(
        _ armoredPassphrase: ArmoredMessage,
        armoredSignature: ArmoredSignature,
        verificationKeys: [ArmoredKey],
        decryptionKeys: [DecryptionKey]
    ) throws -> VerifiedText {
        try decryptAndVerifyDetachedTextMessage(armoredPassphrase, armoredSignature, decryptionKeys, verificationKeys)
    }

    static func decryptAndVerifyNodeHashKey(
        _ nodeHashKey: Armored,
        decryptionKeys: [DecryptionKey],
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedText {
        try decryptAndVerifyAttachedTextMessage(nodeHashKey, decryptionKeys: decryptionKeys, verificationKeys: verificationKeys)
    }

    static func decryptAndVerifyContentKeyPacket(
        _ keyPacket: Data,
        decryptionKey: DecryptionKey,
        signature: ArmoredSignature?,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        let decryptionKeyRing = try buildPrivateKeyRing(decryptionKeys: [decryptionKey])
        defer { decryptionKeyRing.clearPrivateParams() }

        let sessionKey = try unwrap { try decryptionKeyRing.decryptSessionKey(keyPacket).key }
        let verificationKeyRing = try buildPublicKeyRing(armoredKeys: verificationKeys)

        guard let armoredSignature = signature else {
            return .unverified(sessionKey, DriveSignatureError())
        }

        let signature = CryptoPGPSignature(fromArmored: armoredSignature)

        do {
            // First attempt to verify the signature with the SessionKey (new schema)
            let plainMessage = CryptoPlainMessage(sessionKey)
            try verificationKeyRing.verifyDetached(plainMessage, signature: signature, verifyTime: CryptoGetUnixTime())
            return .verified(sessionKey)
        } catch { }

        do {
            // On failure attempt to verify the signature with the KeyPacket (old iOS generated files)
            let plainMessage = CryptoPlainMessage(keyPacket)
            try verificationKeyRing.verifyDetached(plainMessage, signature: signature, verifyTime: CryptoGetUnixTime())
            return .verified(sessionKey)
        } catch {
            return .unverified(sessionKey, error)
        }
    }

    static func decryptAndVerifyXAttributes(
        _ xattr: ArmoredMessage,
        decryptionKey: DecryptionKey,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        try decryptAndVerifyAttachedBinaryMessage(xattr, decryptionKeys: [decryptionKey], verificationKeys: verificationKeys)
    }

    static func decryptBlockSignature(
        _ encryptedSignature: ArmoredMessage,
        _ nodeKey: DecryptionKey
    ) throws -> ArmoredSignature {
        let plainMessage = try decryptMessage(encryptedSignature, [nodeKey])
        let armoredSignature = try executeAndUnwrap { CryptoPGPSignature(plainMessage.getBinary())?.getArmored(&$0) }
        return armoredSignature
    }

    static func decryptAndVerifyBlock(
        _ blockDataPacket: DataPacket,
        sessionKey: SessionKey,
        signature: ArmoredSignature,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        try decryptAndVerifyDetachedBinaryMessage(blockDataPacket, sessionKey, signature, verificationKeys)
    }

    static func verifyManifestSignature(
        _ manifestSignature: Data,
        _ signature: ArmoredSignature,
        verificationKeys: [ArmoredKey]
    ) throws {
        let plainMessage = try unwrap { CryptoPlainMessage(manifestSignature) }
        try verifyDetached(plainMessage, signature, verificationKeys)
    }

    static func decryptAndVerifyThumbnail(
        _ thumbnailDataPacket: DataPacket,
        contentSessionKey: SessionKey,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        try decryptAndVerifyAttachedUnarmoredBinary(
            dataPacket: thumbnailDataPacket,
            sessionKey: contentSessionKey,
            verificationKeys: verificationKeys
        )
    }

    static func decryptAndVerifyExif(
        _ exifDataPacket: DataPacket,
        contentSessionKey: SessionKey,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        try decryptAndVerifyAttachedUnarmoredBinary(
            dataPacket: exifDataPacket,
            sessionKey: contentSessionKey,
            verificationKeys: verificationKeys
        )
    }

    static func decryptAndVerifyMetadata(
        _ metadataDataPacket: DataPacket,
        contentSessionKey: SessionKey,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        try decryptAndVerifyAttachedUnarmoredBinary(
            dataPacket: metadataDataPacket,
            sessionKey: contentSessionKey,
            verificationKeys: verificationKeys
        )
    }
}

extension Decryptor {

    struct VerificationError: Error {
        let message: String?
    }

    // MARK: - General Purpose Swift functions
    static func decryptAndVerifyAttachedTextMessage(
        _ message: ArmoredMessage,
        decryptionKeys: [DecryptionKey],
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedText {
        let explicitMessage = try decryptAndVerifyAttachedMessage(message, decryptionKeys: decryptionKeys, verificationKeys: verificationKeys)

        guard let message = explicitMessage.message?.getString() else {
            throw Errors.emptyResult
        }

        if explicitMessage.signatureVerificationError == nil {
            return .verified(message)
        } else {
            return .unverified(message, VerificationError(message: explicitMessage.signatureVerificationError?.message))
        }
    }

    static func decryptAndVerifyAttachedBinaryMessage(
        _ message: ArmoredMessage,
        decryptionKeys: [DecryptionKey],
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        let explicitMessage = try decryptAndVerifyAttachedMessage(message, decryptionKeys: decryptionKeys, verificationKeys: verificationKeys)

        guard let message = explicitMessage.message?.getBinary() else {
            throw Errors.emptyResult
        }

        if explicitMessage.signatureVerificationError == nil {
            return .verified(message)
        } else {
            return .unverified(message, VerificationError(message: explicitMessage.signatureVerificationError?.message))
        }
    }

    static func decryptAndVerifyDetachedTextMessage(
        _ message: ArmoredMessage,
        _ signature: ArmoredSignature,
        _ decryptionKeys: [DecryptionKey],
        _ verificationKeys: [ArmoredKey]
    ) throws -> VerifiedText {
        let plainMessage = try decryptMessage(message, decryptionKeys)

        do {
            try verifyDetached(plainMessage, signature, verificationKeys)
            return .verified(plainMessage.getString())
        } catch {
            return .unverified(plainMessage.getString(), error)
        }
    }

    static func decryptAndVerifyDetachedBinaryMessage(
        _ message: ArmoredMessage,
        _ signature: ArmoredSignature,
        _ decryptionKeys: [DecryptionKey],
        _ verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        let plainMessage = try decryptMessage(message, decryptionKeys)
        guard let binary = plainMessage.getBinary() else { throw Errors.emptyResult }

        do {
            try verifyDetached(plainMessage, signature, verificationKeys)
            return .verified(binary)
        } catch {
            return .unverified(binary, error)
        }
    }

    // MARK: - Crypto/Go interacting functions
    private static func decryptAndVerifyAttachedMessage(
        _ message: ArmoredMessage,
        decryptionKeys: [DecryptionKey],
        verificationKeys: [ArmoredKey]
    ) throws -> HelperExplicitVerifyMessage {
        let decryptionKeyRing = try buildPrivateKeyRing(decryptionKeys: decryptionKeys)
        defer { decryptionKeyRing.clearPrivateParams() }

        let pgpMessage = CryptoPGPMessage(fromArmored: message)
        let verificationKeyRing = try buildPublicKeyRing(armoredKeys: verificationKeys)

        let explicitMessage = try executeAndUnwrap {
            HelperDecryptExplicitVerify(pgpMessage, decryptionKeyRing, verificationKeyRing, CryptoGetUnixTime(), &$0)
        }

        return explicitMessage
    }

    static func decryptAndVerifyAttachedUnarmoredBinary(
        dataPacket: DataPacket,
        sessionKey: SessionKey,
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        let cryptoSessionKey = try makeCryptoSessionKey(sessionKey)
        let verificationKeyRing = try buildPublicKeyRing(armoredKeys: verificationKeys)

        let explicitMessage = try executeAndUnwrap {
            HelperDecryptSessionKeyExplicitVerify(dataPacket, cryptoSessionKey, verificationKeyRing, CryptoGetUnixTime(), &$0)
        }

        guard let message = explicitMessage.message?.getBinary() else {
            throw Errors.emptyResult
        }

        if explicitMessage.signatureVerificationError == nil {
            return .verified(message)
        } else {
            return .unverified(message, VerificationError(message: explicitMessage.signatureVerificationError?.message))
        }
    }

    private static func decryptAndVerifyDetachedBinaryMessage(
        _ dataPacket: DataPacket,
        _ sessionKey: SessionKey,
        _ signature: ArmoredSignature,
        _ verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        let cryptoSessionKey = try makeCryptoSessionKey(sessionKey)
        let plainMessage = try cryptoSessionKey.decrypt(dataPacket)
        guard let binary = plainMessage.getBinary() else { throw Errors.emptyResult }

        do {
            try verifyDetached(plainMessage, signature, verificationKeys)
            return .verified(binary)
        } catch {
            return .unverified(binary, error)
        }
    }

    private static func decryptMessage(
        _ armoredMessage: ArmoredMessage,
        _ decryptionKeys: [DecryptionKey]
    ) throws -> CryptoPlainMessage {
        let decryptionKeyRing = try CoreDecryptor.buildPrivateKeyRing(with: decryptionKeys)
        defer { decryptionKeyRing.clearPrivateParams() }

        let pgpMsg = CryptoPGPMessage(fromArmored: armoredMessage)
        let plainMsg = try decryptionKeyRing.decrypt(pgpMsg, verifyKey: nil, verifyTime: 0)
        return plainMsg
    }

    private static func verifyDetached(
        _ message: CryptoPlainMessage,
        _ signature: ArmoredSignature,
        _ verificationKeys: [ArmoredKey]
    ) throws {
        let verificationKeyRing = try unwrap { try CoreDecryptor.buildPublicKeyRing(armoredKeys: verificationKeys) }
        let pgpSignature = CryptoPGPSignature(fromArmored: signature)
        try verificationKeyRing.verifyDetached(message, signature: pgpSignature, verifyTime: CryptoGetUnixTime())
    }

    static func hashSha256(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, UInt32(data.count), &digest)
        }
        
        return Data(digest)
    }
}

extension Decryptor {
    static func buildPublicKeyRing(armoredKeys: [String]) throws -> CryptoKeyRing {
        guard let keyRing = try CoreDecryptor.buildPublicKeyRing(armoredKeys: armoredKeys) else {
            throw Errors.couldNotCreateKeyRing
        }
        return keyRing
    }

    static func buildPrivateKeyRing(decryptionKeys: [DecryptionKey]) throws -> CryptoKeyRing {
        try CoreDecryptor.buildPrivateKeyRing(with: decryptionKeys)
    }

    private static func makeCryptoSessionKey(_ contentSessionKey: Data) throws -> CryptoSessionKey {
        try unwrap { CryptoNewSessionKeyFromToken(contentSessionKey, ConstantsAES256) }
    }
}

extension Decryptor {
    static func decryptSessionKey(_ message: ArmoredMessage, decryptionKeys: [DecryptionKey]) throws -> Data {
        let keyPacket = try unwrap { CryptoPGPSplitMessage(fromArmored: message)?.keyPacket }
        return try decryptSessionKey(keyPacket, decryptionKeys: decryptionKeys)
    }

    static func decryptSessionKey(_ keyPacket: KeyPacket, decryptionKeys: [DecryptionKey]) throws -> Data {
        let decryptionKeyRing = try buildPrivateKeyRing(decryptionKeys: decryptionKeys)
        defer { decryptionKeyRing.clearPrivateParams() }
        return try unwrap { try decryptionKeyRing.decryptSessionKey(keyPacket).key }
    }
}

extension Decryptor {
    static func randomPassword(ofSize size: Int) -> String {
        let charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<size).map { _ in charset.randomElement()! })
    }

    struct SRP {
        let verifier: Data
        let salt: Data
    }

    static func srpForPassword(_ password: String, modulus: String) throws -> SRP {
        let salt = try execute { SrpRandomBits(80, &$0) }.forceUnwrap()
        let auth = try executeAndUnwrap { SrpNewAuthForVerifier(password.data(using: .utf8), modulus, salt, &$0) }
        let verifier = try auth.generateVerifier(2048)

        return SRP(verifier: verifier, salt: salt)
    }

    struct HashedPassword {
        let hash: String
        let salt: Data
    }

    static func bcryptPassword(_ password: String) throws -> HashedPassword {
        /*
         bcrypt is a password-hashing function whose output has the following form:
         $2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW
         \__/\/ \____________________/\_____________________________/
         Alg Cost      Salt                        Hash
         |___________ 29 ____________|
         */

        let salt = try execute { SrpRandomBits(128, &$0) }.forceUnwrap()
        let bcryptedPassword = try executeAndUnwrap { SrpMailboxPassword(password.data(using: .utf8), salt, &$0) }

        var hash = try unwrap { String(data: bcryptedPassword, encoding: .utf8) }
        // Remove bcrypt prefix and salt (first 29 characters)
        hash.removeFirst(29)

        return HashedPassword(hash: hash, salt: salt)
    }

    static func encryptSessionKey(_ sessionKey: Data, with password: String) throws -> KeyPacket {
        let cryptoSessionKey = try makeCryptoSessionKey(sessionKey)
        let keyPacket = try executeAndUnwrap {
            CryptoEncryptSessionKeyWithPassword(cryptoSessionKey, password.data(using: .utf8), &$0)
        }
        return keyPacket
    }
}
