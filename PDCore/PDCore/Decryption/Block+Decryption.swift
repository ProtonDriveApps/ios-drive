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

    private var blockPath: URL? {
        if let localUrl,
           FileManager.default.fileExists(atPath: localUrl.path) {
            return localUrl
        } else if let permanentUrl,
                  FileManager.default.fileExists(atPath: permanentUrl.path) {
            return permanentUrl
        } else {
            return nil
        }
    }

    internal func decrypt(with contentSessionKey: SessionKey, decryptionResource: DecryptionResource = Decryptor()) throws -> Data {
        do {
            guard let blockPath else {
                throw Errors.blockDataNotDownloaded
            }

            let blockDataPacket = try Data(contentsOf: blockPath)
            guard !blockDataPacket.isEmpty, revision.size > 0 else {
                // empty file does not require decryption
                return Data()
            }
            let locallyCalculatedHash = Decryptor.hashSha256(blockDataPacket)
            guard locallyCalculatedHash == sha256 else { throw Errors.tamperedBlock }

            do {
                return try decryptionResource.decryptBlock(blockDataPacket, sessionKey: contentSessionKey)
            } catch let error where !(error is Decryptor.Errors) {
                DriveIntegrityErrorMonitor.reportContentError(for: revision.file)
                throw error
            }
        } catch {
            Log.error(error: DecryptionError(error, "Block", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nVolumeID: \(revision.file.volumeID)"), domain: .encryption)
            throw error
        }
    }

    public func decrypt(to clearUrl: URL, decryptionResource: DecryptionResource = Decryptor()) throws {
        do {
            let file = self.revision.file
            guard let contentKeyPacket = file.contentKeyPacket,
                  let keyPacket = Data(base64Encoded: contentKeyPacket) else
            {
                throw Errors.noFileMeta
            }

            guard let localUrl = self.localUrl, FileManager.default.fileExists(atPath: localUrl.path) else {
                throw Errors.blockDataNotDownloaded
            }

            let passphrase = try file.decryptPassphrase()
            let blockDecryptionKey = DecryptionKey(privateKey: file.nodeKey, passphrase: passphrase)
            try decryptionResource.decryptBinaryInStream(
                cyphertextUrl: localUrl,
                cleartextUrl: clearUrl,
                decryptionKeys: [blockDecryptionKey],
                keyPacket: keyPacket
            )

        } catch {
            Log.error(error: DecryptionError(error, "Block - stream", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nVolumeID: \(revision.file.volumeID)"), domain: .encryption)
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
