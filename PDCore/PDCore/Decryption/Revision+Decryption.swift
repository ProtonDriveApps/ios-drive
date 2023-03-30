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

extension Revision {
    enum Errors: Error {
        case noBlocks, noFileMeta, cancelled
        case noManifestSignature
        case noSignatureAddress
    }
    
    public func blocksAreValid() -> Bool {
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
    
    // when we do not care of cancelling
    public func decryptFile() throws -> URL {
        var isCancelled = false
        return try self.decryptFile(isCancelled: &isCancelled)
    }
    
    // when we may want to canel
    public func decryptFile(isCancelled: inout Bool) throws -> URL {
        // For GA we just silently let the decryption pass
        do {
            try checkManifestSignatureForDownloadedRevisions()
        } catch {
            ConsoleLogger.shared?.log(SignatureError(error, "Revision"))
        }

        if Constants.runningInExtension {
            do {
                return try decryptFileInStream(isCancelled: &isCancelled)
            } catch {
                ConsoleLogger.shared?.log(DecryptionError(error, "Revision - stream"))
                throw error
            }
        } else {
            do {
                return try decryptFileInMemory(isCancelled: &isCancelled)
            } catch {
                ConsoleLogger.shared?.log(DecryptionError(error, "Revision"))
                throw error
            }
        }
    }

    public func decryptExtendedAttributes() throws -> ExtendedAttributes {
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
                return xAttr

            case .unverified(let attributes, let error):
                ConsoleLogger.shared?.log(SignatureError(error, "ExtendedAttributes"))
                let xAttr = try JSONDecoder().decode(ExtendedAttributes.self, from: attributes)
                return xAttr
            }

        } catch {
            ConsoleLogger.shared?.log(DecryptionError(error, "ExtendedAttributes"))
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
        fileHandle.seekToEndOfFile()
        
        for block in blocks.dropFirst() {
            guard !isCancelled else { break }
            try autoreleasepool {
                let blockData = try block.decrypt(with: sessionKey)
                fileHandle.write(blockData)
            }
        }
        
        fileHandle.closeFile()
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
        
        var clearBlockUrls: [URL] = []
        for (index, block) in blocks.enumerated() {
            guard !isCancelled else { break }
            let clearBlockUrl = try self.clearURL().appendingPathExtension("\(index)")
            try block.decrypt(to: clearBlockUrl)
            clearBlockUrls.append(clearBlockUrl)
        }
        
        let clearFileUrl = try clearURL()
        try FileManager.default.merge(files: clearBlockUrls, to: clearFileUrl, chunkSize: Constants.maxBlockChunkSize)
        
        if isCancelled {
            try? FileManager.default.removeItem(at: clearFileUrl)
            throw Errors.cancelled
        }
        
        return clearFileUrl
    }

    public func clearURL() throws -> URL {
        let filename = try file.decryptName()
        return PDFileManager.cleartextCacheDirectory.appendingPathComponent(filename)
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
            try? moc.save()
        }
    }

    internal func getAddressPublicKeysOfRevisionCreator() throws -> [PublicKey] {
        guard let signatureAddress = signatureAddress else {
            throw Errors.noSignatureAddress
        }
        guard case let publicKeys = SessionVault.current.getPublicKeys(for: signatureAddress), !publicKeys.isEmpty else {
            throw SessionVault.Errors.noRequiredAddressKey
        }
        return publicKeys
    }

    private func sortedBlocks() -> [Block] {
        blocks.sorted(by: { $0.index < $1.index })
    }

    private func checkManifestSignatureForDownloadedRevisions() throws {
        guard let armoredManifestSignature = manifestSignature else { throw Errors.noManifestSignature }

        let revisionCreatorAddressKeys = try getAddressPublicKeysOfRevisionCreator()

        var contentHashes: [Data] = sortedBlocks().compactMap { $0.sha256 }
        if let base64ThumbnailHash = thumbnailHash,
           let thumbnailHash = Data(base64Encoded: base64ThumbnailHash) {
            contentHashes.insert(thumbnailHash, at: 0)
        }
        let localManifest = Data(contentHashes.joined())

        try Decryptor.verifyManifestSignature(localManifest, armoredManifestSignature, verificationKeys: revisionCreatorAddressKeys)
    }
}
