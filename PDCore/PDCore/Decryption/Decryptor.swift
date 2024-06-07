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
import ProtonCoreCrypto
import ProtonCoreCryptoGoInterface
import ProtonCoreKeyManager
import ProtonCoreAuthentication
import ProtonCoreDataModel
import CommonCrypto

/// ProtonCoreKeyManager framework provides a number of static methods - high-level API to work with Crypto.xcframework
/// This class gives us space to override that functional
class Decryptor {
    
    typealias CoreDecryptor = ProtonCoreKeyManager.Decryptor
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

    static func decryptContentKeyPacket(
        _ keyPacket: Data,
        decryptionKey: DecryptionKey
    ) throws -> Data {
        let decryptionKeyRing = try buildPrivateKeyRing(decryptionKeys: [decryptionKey])
        defer { decryptionKeyRing.clearPrivateParams() }
        return try unwrap { try decryptionKeyRing.decryptSessionKey(keyPacket).key }
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

        let signature = CryptoGo.CryptoPGPSignature(fromArmored: armoredSignature)

        do {
            // First attempt to verify the signature with the SessionKey (new schema)
            let plainMessage = CryptoGo.CryptoPlainMessage(sessionKey)
            try verificationKeyRing.verifyDetached(plainMessage, signature: signature, verifyTime: CryptoGo.CryptoGetUnixTime())
            return .verified(sessionKey)
        } catch { }

        do {
            // On failure attempt to verify the signature with the KeyPacket (old iOS generated files)
            let plainMessage = CryptoGo.CryptoPlainMessage(keyPacket)
            try verificationKeyRing.verifyDetached(plainMessage, signature: signature, verifyTime: CryptoGo.CryptoGetUnixTime())
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
        let armoredSignature = try executeAndUnwrap { CryptoGo.CryptoPGPSignature(plainMessage.getBinary())?.getArmored(&$0) }
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
        let plainMessage = try unwrap { CryptoGo.CryptoPlainMessage(manifestSignature) }
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
        defer {
            Crypto.freeGolangMem()
        }
        let explicitMessage = try decryptAndVerifyAttachedMessage(message, decryptionKeys: decryptionKeys, verificationKeys: verificationKeys)

        guard let message = explicitMessage.messageGoCrypto?.getString() else {
            throw Errors.emptyResult
        }

        if explicitMessage.signatureVerificationErrorGoCrypto == nil {
            return .verified(message)
        } else {
            return .unverified(message, VerificationError(message: explicitMessage.signatureVerificationErrorGoCrypto?.message))
        }
    }

    static func decryptAndVerifyAttachedBinaryMessage(
        _ message: ArmoredMessage,
        decryptionKeys: [DecryptionKey],
        verificationKeys: [ArmoredKey]
    ) throws -> VerifiedBinary {
        defer {
            Crypto.freeGolangMem()
        }
        let explicitMessage = try decryptAndVerifyAttachedMessage(message, decryptionKeys: decryptionKeys, verificationKeys: verificationKeys)

        guard let message = explicitMessage.messageGoCrypto?.getBinary() else {
            throw Errors.emptyResult
        }

        if explicitMessage.signatureVerificationErrorGoCrypto == nil {
            return .verified(message)
        } else {
            return .unverified(message, VerificationError(message: explicitMessage.signatureVerificationErrorGoCrypto?.message))
        }
    }

    static func decryptAndVerifyDetachedTextMessage(
        _ message: ArmoredMessage,
        _ signature: ArmoredSignature,
        _ decryptionKeys: [DecryptionKey],
        _ verificationKeys: [ArmoredKey]
    ) throws -> VerifiedText {
        defer {
            Crypto.freeGolangMem()
        }
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

        let pgpMessage = CryptoGo.CryptoPGPMessage(fromArmored: message)
        let verificationKeyRing = try buildPublicKeyRing(armoredKeys: verificationKeys)

        let explicitMessage = try executeAndUnwrap {
            CryptoGo.HelperDecryptExplicitVerify(pgpMessage, decryptionKeyRing, verificationKeyRing, CryptoGo.CryptoGetUnixTime(), &$0)
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
            CryptoGo.HelperDecryptSessionKeyExplicitVerify(dataPacket, cryptoSessionKey, verificationKeyRing, CryptoGo.CryptoGetUnixTime(), &$0)
        }

        guard let message = explicitMessage.messageGoCrypto?.getBinary() else {
            throw Errors.emptyResult
        }

        if explicitMessage.signatureVerificationErrorGoCrypto == nil {
            return .verified(message)
        } else {
            return .unverified(message, VerificationError(message: explicitMessage.signatureVerificationErrorGoCrypto?.message))
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

        let pgpMsg = CryptoGo.CryptoPGPMessage(fromArmored: armoredMessage)
        let plainMsg = try decryptionKeyRing.decrypt(pgpMsg, verifyKey: nil, verifyTime: 0)
        return plainMsg
    }

    private static func verifyDetached(
        _ message: CryptoPlainMessage,
        _ signature: ArmoredSignature,
        _ verificationKeys: [ArmoredKey]
    ) throws {
        let verificationKeyRing = try unwrap { try CoreDecryptor.buildPublicKeyRing(armoredKeys: verificationKeys) }
        let pgpSignature = CryptoGo.CryptoPGPSignature(fromArmored: signature)
        try verificationKeyRing.verifyDetached(message, signature: pgpSignature, verifyTime: CryptoGo.CryptoGetUnixTime())
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
        try unwrap { CryptoGo.CryptoNewSessionKeyFromToken(contentSessionKey, CryptoGo.ConstantsAES256) }
    }
}

extension Decryptor {
    static func decryptSessionKey(_ message: ArmoredMessage, decryptionKeys: [DecryptionKey]) throws -> Data {
        let keyPacket = try unwrap { CryptoGo.CryptoPGPSplitMessage(fromArmored: message)?.keyPacket }
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
        let salt = try execute { CryptoGo.SrpRandomBits(80, &$0) }.forceUnwrap()
        let auth = try executeAndUnwrap { CryptoGo.SrpNewAuthForVerifier(password.data(using: .utf8), modulus, salt, &$0) }
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

        let salt = try execute { CryptoGo.SrpRandomBits(128, &$0) }.forceUnwrap()
        let bcryptedPassword = try executeAndUnwrap { CryptoGo.SrpMailboxPassword(password.data(using: .utf8), salt, &$0) }

        var hash = try unwrap { String(data: bcryptedPassword, encoding: .utf8) }
        // Remove bcrypt prefix and salt (first 29 characters)
        hash.removeFirst(29)

        return HashedPassword(hash: hash, salt: salt)
    }

    static func encryptSessionKey(_ sessionKey: Data, with password: String) throws -> KeyPacket {
        let cryptoSessionKey = try makeCryptoSessionKey(sessionKey)
        let keyPacket = try executeAndUnwrap {
            CryptoGo.CryptoEncryptSessionKeyWithPassword(cryptoSessionKey, password.data(using: .utf8), &$0)
        }
        return keyPacket
    }
}

extension Decryptor: DecryptionResource {

    func decryptKeyPacket(_ keyPacket: Data, decryptionKey: DecryptionKey) throws -> Data {
        try Decryptor.decryptContentKeyPacket(keyPacket, decryptionKey: decryptionKey)
    }

    func decryptInStream(url: URL, sessionKey: Data) throws {
        let readFileHandle = try FileHandle(forReadingFrom: url)
        defer { try? readFileHandle.close() }
        let cryptoSesionKey = try Decryptor.makeCryptoSessionKey(sessionKey)
        return try decryptInStream(
            sessionKey: cryptoSesionKey,
            ciphertextFile: readFileHandle,
            bufferSize: Constants.maxBlockChunkSize
        )
    }

    private func decryptInStream(sessionKey: CryptoSessionKey, ciphertextFile: FileHandle, bufferSize: Int) throws {
        let ciphertextReader = CryptoGo.HelperMobile2GoReader(FileMobileReader(file: ciphertextFile))

        let plaintextMessageReader = try sessionKey.decryptStream(ciphertextReader, verifyKeyRing: nil, verifyTime: CryptoGo.CryptoGetUnixTime())
        let reader = CryptoGo.HelperGo2IOSReader(plaintextMessageReader)!
        var isEOF: Bool = false
        while !isEOF {
            try autoreleasepool {
                let result = try reader.read(bufferSize)
                isEOF = result.isEOF
            }
        }
    }
}
