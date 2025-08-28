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
import ProtonCoreCryptoGoInterface

extension Decryptor {
    
    // Marin: Adding this method defeats the point of giving the session key and key rings directly. Which were used to avoid decrypting and building the objects for each block
    // swiftlint:disable:next function_parameter_count
    static func decryptStream(_ cyphertextUrl: URL,
                              _ cleartextUrl: URL,
                              _ decryptionKeys: [DecryptionKey],
                              _ keyPacket: Data,
                              _ verificationKeys: [ArmoredKey],
                              _ signature: String,
                              isSignatureVerifiable: (() -> Bool)) throws
    {
        // prepare files
        if FileManager.default.fileExists(atPath: cleartextUrl.path) {
            try FileManager.default.removeItem(at: cleartextUrl)
        }
        FileManager.default.createFile(atPath: cleartextUrl.path, contents: Data(), attributes: nil)

        let readFileHandle = try FileHandle(forReadingFrom: cyphertextUrl)
        defer { try? readFileHandle.close() }
        let writeFileHandle = try FileHandle(forWritingTo: cleartextUrl)
        defer { try? writeFileHandle.close() }
        // cryptography

        let decryptionKeyRing = try CoreDecryptor.buildPrivateKeyRing(with: decryptionKeys)
        defer { decryptionKeyRing.clearPrivateParams() }
        let sessionKey = try decryptionKeyRing.decryptSessionKey(keyPacket)

        try Decryptor.decryptBinaryStream(sessionKey, nil, readFileHandle, writeFileHandle, Constants.maxBlockChunkSize)

        let verifyFileHandle = try FileHandle(forReadingFrom: cleartextUrl)
        defer { try? verifyFileHandle.close() }
        let verificationKeyRing = try buildPublicKeyRing(armoredKeys: verificationKeys)

        do {
            try Decryptor.verifyStreamWithEncryptedSignature(verificationKeyRing, decryptionKeyRing, verifyFileHandle, signature)
        } catch {
            Log.error("verifyStreamWithEncryptedSignature failed", error: SignatureError(error, "Block - stream"), domain: .encryption, sendToSentryIfPossible: isSignatureVerifiable())
        }
    }
}

// MARK: - CryptoKeyRing decryption helpers
extension Decryptor {
    private static func verifyStreamWithEncryptedSignature(_ verifyKeyRing: CryptoKeyRing,
                                                           _ decryptKeyRing: CryptoKeyRing,
                                                           _ plaintextFile: FileHandle,
                                                           _ encSignatureArmored: String) throws
    {
        let plaintextReader = CryptoGo.HelperMobile2GoReader(FileMobileReader(file: plaintextFile))
        
        let encSignature = CryptoGo.CryptoPGPMessage(fromArmored: encSignatureArmored)

        try verifyKeyRing.verifyDetachedEncryptedStream(
            plaintextReader,
            encryptedSignature: encSignature,
            decryptionKeyRing: decryptKeyRing,
            verifyTime: CryptoGo.CryptoGetUnixTime()
        )
    }
    
    private static func decryptBinaryStream(_ sessionKey: CryptoSessionKey,
                                            _ verifyKeyRing: CryptoKeyRing?,
                                            _ ciphertextFile: FileHandle,
                                            _ blockFile: FileHandle,
                                            _ bufferSize: Int) throws
    {
        
        let ciphertextReader = CryptoGo.HelperMobile2GoReader(FileMobileReader(file: ciphertextFile))
        
        let plaintextMessageReader = try sessionKey.decryptStream(
            ciphertextReader,
            verifyKeyRing: verifyKeyRing,
            verifyTime: CryptoGo.CryptoGetUnixTime()
        )

        let reader = CryptoGo.HelperGo2IOSReader(plaintextMessageReader)!
        var isEOF: Bool = false
        while !isEOF {
            try autoreleasepool {
                let result = try reader.read(bufferSize)
                try blockFile.write(contentsOf: result.data ?? Data())
                isEOF = result.isEOF
            }
        }

        if verifyKeyRing != nil {
            try plaintextMessageReader.verifySignature()
        }
    }
}
