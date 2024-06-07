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

extension Block {
    enum Errors: Error {
        case noFileMeta, blockDataNotDownloaded
        case blockIsNotReadyForMoving
        case noEncryptedSignatureOrEmail
        case tamperedBlock
    }

    internal func decrypt(with contentSessionKey: SessionKey) throws -> Data {
        do {
            guard let localUrl = self.localUrl, FileManager.default.fileExists(atPath: localUrl.path) else {
                throw Errors.blockDataNotDownloaded
            }

            let blockDataPacket = try Data(contentsOf: localUrl)
            guard !blockDataPacket.isEmpty, revision.size > 0 else {
                // empty file does not require decryption
                return Data()
            }

            guard let encryptedBlockSignature = encSignature else {
                throw Errors.noEncryptedSignatureOrEmail
            }

            let locallyCalculatedHash = Decryptor.hashSha256(blockDataPacket)
            guard locallyCalculatedHash == sha256 else { throw Errors.tamperedBlock }

            let nodeKey = revision.file.nodeKey
            let nodePassphrase = try revision.file.decryptPassphrase()
            let nodeDecryptionKey = DecryptionKey(privateKey: nodeKey, passphrase: nodePassphrase)

            let decryptedBlockSignature = try Decryptor.decryptBlockSignature(encryptedBlockSignature, nodeDecryptionKey)
            let addressKeys = try getAddressPublicKeysOfBlockCreator()
            let decrypted = try Decryptor.decryptAndVerifyBlock(
                blockDataPacket,
                sessionKey: contentSessionKey,
                signature: decryptedBlockSignature,
                verificationKeys: addressKeys
            )

            switch decrypted {
            case .verified(let cleardata):
                return cleardata
            case .unverified(let cleardata, let error):
                Log.error(SignatureError(error, "Block", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nShareID: \(revision.file.shareID)"), domain: .encryption)
                return cleardata
            }
        } catch {
            Log.error(DecryptionError(error, "Block", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nShareID: \(revision.file.shareID)"), domain: .encryption)
            throw error
        }
    }

    public func decrypt(to clearUrl: URL) throws {
        do {
            let file = self.revision.file
            guard let contentKeyPacket = file.contentKeyPacket,
                  let keyPacket = Data(base64Encoded: contentKeyPacket) else
            {
                throw Errors.noFileMeta
            }

            guard let signature = self.encSignature else {
                throw Errors.noEncryptedSignatureOrEmail
            }

            guard let localUrl = self.localUrl, FileManager.default.fileExists(atPath: localUrl.path) else {
                throw Errors.blockDataNotDownloaded
            }

            let passphrase = try file.decryptPassphrase()
            let blockDecryptionKey = DecryptionKey(privateKey: file.nodeKey, passphrase: passphrase)
            let verificationKeys = try getAddressPublicKeysOfBlockCreator()

            try Decryptor.decryptStream(localUrl, clearUrl, [blockDecryptionKey], keyPacket, verificationKeys, signature)

        } catch {
            Log.error(DecryptionError(error, "Block - stream", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nShareID: \(revision.file.shareID)"), domain: .encryption)
            throw error
        }
    }

    private func getAddressPublicKeysOfBlockCreator() throws -> [PublicKey] {
        guard let signatureEmail = signatureEmail else {
            throw Errors.noEncryptedSignatureOrEmail
        }
        return SessionVault.current.getPublicKeys(for: signatureEmail)
    }
}

extension Block.Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .blockDataNotDownloaded: return "Block data is not downloaded"
        case .blockIsNotReadyForMoving: return "Block is not ready for move"
        case .noEncryptedSignatureOrEmail: return "Block does not have encrypted signature or creator"
        case .noFileMeta: return "Block is not connected to File"
        case .tamperedBlock: return "The block has associated an invalid hash"
        }
    }
}
