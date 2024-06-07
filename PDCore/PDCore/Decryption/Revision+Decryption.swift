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

extension Revision {
    enum Errors: Error {
        case noBlocks
        case noFileMeta
        case cancelled
        case noManifestSignature
        case noSignatureAddress
    }
    
    public func blocksAreValid() -> Bool {
        guard let moc = self.moc else {
            return false
        }
        return moc.performAndWait {
            guard !self.blocks.isEmpty else {
                return false
            }
            for block in self.blocks {
                guard let localUrl = block.localUrl, FileManager.default.fileExists(atPath: localUrl.path) else {
                    return false
                }
            }
            
            return true
        }
    }
    
    // when we do not care of cancelling
    public func decryptFile() throws -> URL {
        var isCancelled = false
        return try self.decryptFile(isCancelled: &isCancelled)
    }
    
    // when we may want to cancel
    public func decryptFile(isCancelled: inout Bool) throws -> URL {
        // For GA we just silently let the decryption pass
        do {
            try checkManifestSignatureForDownloadedRevisions()
        } catch {
            Log.error(SignatureError(error, "Revision", description: "RevisionID: \(id) \nLinkID: \(file.id) \nShareID: \(file.shareID)"), domain: .encryption)
        }

        if Constants.runningInExtension {
            do {
                return try decryptFileInStream(isCancelled: &isCancelled)
            } catch {
                Log.error(DecryptionError(error, "Revision - stream", description: "RevisionID: \(id) \nLinkID: \(file.id) \nShareID: \(file.shareID)"), domain: .encryption)
                throw error
            }
        } else {
            do {
                return try decryptFileInMemory(isCancelled: &isCancelled)
            } catch {
                Log.error(DecryptionError(error, "Revision", description: "RevisionID: \(id) \nLinkID: \(file.id) \nShareID: \(file.shareID)"), domain: .encryption)
                throw error
            }
        }
    }

    public func decryptedExtendedAttributes() throws -> ExtendedAttributes {
        guard let moc = self.moc else {
            throw Revision.noMOC()
        }

        return try moc.performAndWait {
            return try unsafeDecryptedExtendedAttributes()
        }
    }

    public func unsafeDecryptedExtendedAttributes() throws -> ExtendedAttributes {
        return try clearXAttributes ?? decryptExtendedAttributes()
    }

    private func decryptExtendedAttributes() throws -> ExtendedAttributes {
        do {
            guard let xAttributes = xAttributes else {
                throw Errors.noFileMeta
            }

            let filePassphrase = try file.decryptPassphrase()
            let fileKey = file.nodeKey
            let nodeDecryptionKey = DecryptionKey(privateKey: fileKey, passphrase: filePassphrase)
            let addressKeys = try getAddressPublicKeysOfRevisionCreator()

            let decrypted = try Decryptor.decryptAndVerifyXAttributes(
                xAttributes,
                decryptionKey: nodeDecryptionKey,
                verificationKeys: addressKeys
            )

            switch decrypted {
            case .verified(let attributes):
                let xAttr = try JSONDecoder().decode(ExtendedAttributes.self, from: attributes)
                clearXAttributes = xAttr
                return xAttr

            case .unverified(let attributes, let error):
                Log.error(SignatureError(error, "ExtendedAttributes", description: "RevisionID: \(id) \nLinkID: \(file.id) \nShareID: \(file.shareID)"), domain: .encryption)
                let xAttr = try JSONDecoder().decode(ExtendedAttributes.self, from: attributes)
                clearXAttributes = xAttr
                return xAttr
            }

        } catch {
            Log.error(DecryptionError(error, "ExtendedAttributes", description: "RevisionID: \(id) \nLinkID: \(file.id) \nShareID: \(file.shareID)"), domain: .encryption)
            throw error
        }
    }

    internal func decryptContentSessionKey() throws -> Data {
        try file.decryptContentKeyPacket()
    }
    
    func decryptFileInMemory(isCancelled: inout Bool) throws -> URL {
        let sessionKey = try decryptContentSessionKey()

        let clearUrl = try clearURL()
        let blocks = self.blocks.sorted(by: { $0.index < $1.index })
        guard !blocks.isEmpty, !isCancelled else {
            throw Errors.noBlocks
        }

        if FileManager.default.fileExists(atPath: clearUrl.path) {
            try? FileManager.default.removeItem(at: clearUrl)
        }

        try blocks.first?.decrypt(with: sessionKey).write(to: clearUrl)
        let fileHandle = try FileHandle(forWritingTo: clearUrl)
        defer { try? fileHandle.close() }
        
        try fileHandle.seekToEnd()
        
        for block in blocks.dropFirst() {
            guard !isCancelled else { break }
            try autoreleasepool {
                let blockData = try block.decrypt(with: sessionKey)
                try fileHandle.write(contentsOf: blockData)
            }
        }
        
        if isCancelled {
            try? FileManager.default.removeItem(at: clearUrl)
            throw Errors.cancelled
        }
        
        return clearUrl
    }
    
    private func decryptFileInStream(isCancelled: inout Bool) throws -> URL {
        let blocks = self.blocks.sorted(by: { $0.index < $1.index })
        guard !blocks.isEmpty, !isCancelled else {
            throw Errors.noBlocks
        }

        let clearFileUrl = try clearURL()
        var clearBlockUrls: [URL] = []
        try autoreleasepool {
            for (index, block) in blocks.enumerated() {
                guard !isCancelled else { break }
                let clearBlockUrl = clearFileUrl.appendingPathExtension("\(index)")
                try block.decrypt(to: clearBlockUrl)
                clearBlockUrls.append(clearBlockUrl)
            }
            Crypto.freeGolangMem()
        }

        try FileManager.default.merge(files: clearBlockUrls, to: clearFileUrl, chunkSize: Constants.maxBlockChunkSize)
        
        if isCancelled {
            try? FileManager.default.removeItem(at: clearFileUrl)
            throw Errors.cancelled
        }
        
        return clearFileUrl
    }

    public func clearURL() throws -> URL {
        let filename = try file.decryptName()
        return PDFileManager.prepareUrlForFile(named: filename)
    }
    
    public func restoreAfterInvalidBlocksFound() {
        for block in self.blocks where block.localUrl != nil {
            try? FileManager.default.removeItem(at: block.localUrl!)
        }
        
        guard let moc = self.managedObjectContext else {
            assert(false, "Block has no moc")
            return
        }
        
        moc.performAndWait {
            let oldBlocks = self.blocks
            self.blocks.removeAll()
            oldBlocks.forEach(moc.delete)
            try? moc.saveWithParentLinkCheck()
        }
    }

    internal func getAddressPublicKeysOfRevisionCreator() throws -> [PublicKey] {
        guard let signatureAddress = signatureAddress else {
            throw Errors.noSignatureAddress
        }
        return SessionVault.current.getPublicKeys(for: signatureAddress)
    }

    private func sortedBlocks() -> [Block] {
        blocks.sorted(by: { $0.index < $1.index })
    }

    private func checkManifestSignatureForDownloadedRevisions() throws {
        guard let armoredManifestSignature = manifestSignature else { throw Errors.noManifestSignature }

        let revisionCreatorAddressKeys = try getAddressPublicKeysOfRevisionCreator()

        let contentHashes: [Data] = getThumbnailHashes() + sortedBlocks().compactMap { $0.sha256 }
        let localManifest = Data(contentHashes.joined())

        try Decryptor.verifyManifestSignature(localManifest, armoredManifestSignature, verificationKeys: revisionCreatorAddressKeys)
    }

    private func getThumbnailHashes() -> [Data] {
        let thumbnails = Array(thumbnails).sorted(by: { $0.type.rawValue < $1.type.rawValue })
        return thumbnails.compactMap(\.sha256)
    }
}
