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

import CoreData
import ProtonCoreUtilities
import os

final class DiscreteBlocksRevisionEncryptor: RevisionEncryptor {
    private let signersKitFactory: SignersKitFactoryProtocol
    private let maxBlockSize: Int
    private let progress: Progress
    private let moc: NSManagedObjectContext
    private let digestBuilder: DigestBuilder
    private let parallelEncryption: Bool

    private var isCancelled = false
    private var isExecuting = false

    private var localURLs = Atomic<[URL]>([])

    init(
        signersKitFactory: SignersKitFactoryProtocol,
        maxBlockSize: Int,
        progress: Progress,
        moc: NSManagedObjectContext,
        digestBuilder: DigestBuilder,
        parallelEncryption: Bool
    ) {
        self.signersKitFactory = signersKitFactory
        self.maxBlockSize = maxBlockSize
        self.progress = progress
        self.moc = moc
        self.digestBuilder = digestBuilder
        self.parallelEncryption = parallelEncryption
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true

        Task {
            Log.info("STAGE: 1.2 Encrypt blocks 📦📦 started", domain: .uploader)
            do {
                try await encryptThrowing(draft)
                Log.info("STAGE: 1.2 Encrypt blocks 📦📦 finished ✅", domain: .uploader)
                self.progress.complete()
                completion(.success)
            } catch BlockGenerationError.cancelled {
                onCancelBlocksCleanUp()
                // why wasn't the completion block called before?
                completion(.failure(BlockGenerationError.cancelled))
            } catch {
                Log.info("STAGE: 1.2 Encrypt blocks 📦📦 finished ❌", domain: .uploader)
                let userError = mapToUserError(error: error)
                completion(.failure(userError))
            }
        }
    }

    private func encryptThrowing(_ draft: CreatedRevisionDraft) async throws {
        let encryptionMetadata = try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { throw BlockGenerationError.cancelled }
            
            let revision = draft.revision.in(moc: moc)
            let signersKit = try getSignersKit(for: revision)
            let encryptionMetadata = try getEncryptionMetadata(for: revision.file, signersKit: signersKit)
            return encryptionMetadata
        }
        let blocksMetadata: [UploadBlockMetadata]
        if parallelEncryption {
            blocksMetadata = try await encryptBlocksInParallel(draft, encryptionMetadata: encryptionMetadata, signersKit: encryptionMetadata.signersKit)
        } else {
            blocksMetadata = try await encryptBlocks(draft, encryptionMetadata: encryptionMetadata, signersKit: encryptionMetadata.signersKit)
        }

        try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { throw BlockGenerationError.cancelled }
            
            let revision = draft.revision.in(moc: moc)
            revision.removeOldBlocks(in: moc)
            try populateRevision(blocksMetadata, revision: revision, signersKit: encryptionMetadata.signersKit)
            try moc.saveOrRollback()
        }
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
    }

    func onCancelBlocksCleanUp() {
        for url in localURLs.value {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func mapToUserError(error: Error) -> PhotosFailureUserError {
        let nsError = error as NSError
        if nsError.domain == "NSCocoaErrorDomain" {
            return .loadResourceFailed
        }
        return .encryptionFailed
    }
}

extension DiscreteBlocksRevisionEncryptor {

    private func getSignersKit(for revision: Revision) throws -> SignersKit {
        guard !isCancelled else { throw BlockGenerationError.cancelled }
#if os(macOS)
        guard let signatureAddress = revision.signatureAddress else {
            throw RevisionEncryptorError.noSignatureEmailInRevision
        }
        return try signersKitFactory.make(forSigner: .address(signatureAddress))
#else
        let addressID = try revision.file.getContextShareAddressID()
        return try signersKitFactory.make(forAddressID: addressID)
#endif
    }

    private func getEncryptionMetadata(for file: File, signersKit: SignersKit) throws -> EncryptionMetadata {
        guard !isCancelled else { throw BlockGenerationError.cancelled }
        
        guard let rawContentKeyPacket = file.contentKeyPacket,
              let contentKeyPacket = Data(base64Encoded: rawContentKeyPacket) else {
            throw BlockGenerationError.noFileKeyPacket
        }
        guard let signatureEmail = file.signatureEmail else {
            throw RevisionEncryptorError.noSignatureEmailInFile
        }
        let nodePassphrase = try file.decryptPassphrase()
        return EncryptionMetadata(
            nodeKey: file.nodeKey,
            contentKeyPacket: contentKeyPacket,
            passphrase: nodePassphrase,
            signatureEmail: signatureEmail,
            signersKit: signersKit
        )
    }

    private struct UploadBlockMetadata {
        let volumeID: String
        let localPath: String
        let index: Int
        let sha256: Data
        let size: Int
        let clearSize: Int
        let encSignature: String
        let signatureEmail: String
    }

    /// Breaks cleartext file into a number of Blocks
    private func encryptBlocks(_ draft: CreatedRevisionDraft, encryptionMetadata: EncryptionMetadata, signersKit: SignersKit) async throws -> [UploadBlockMetadata] {
        // preparations
        let reader = try FileHandle(forReadingFrom: draft.localURL)
        defer { try? reader.close() }
        let expectedBlockSizes = draft.size.split(divisor: maxBlockSize)
        var blocks: [UploadBlockMetadata] = []

        // Blocks
        var index = 1 // BE starts numeration of blocks from 1
        var data = try reader.read(upToCount: maxBlockSize) ?? Data()
        while !data.isEmpty, !self.isCancelled {
            Log.info("STAGE: 1.2 Encrypting block \(index) 🚧, UUID: \(draft.uploadID)", domain: .uploader)
            try autoreleasepool {

                let pack = NewBlockDataCleartext(index: index, cleardata: data)
                digestBuilder.add(data)
                let encryptedBlock = try Self.encryptBlock(pack, encryptionMetadata: encryptionMetadata)
                let encSignature = try Self.encryptSignature(data, encryptionMetadata: encryptionMetadata, signersKit: signersKit)
                let block = Self.createBlockMetadata(draft.volumeID, encSignature, signersKit.address.email, encryptedBlock, pack)
                try Self.writeEncryptedData(encryptedBlock.cypherdata, for: block, localURLs: self.localURLs)

                // A safeguard to ensure the expected number of blocks read
                guard block.clearSize == expectedBlockSizes[safe: index - 1] else {
                    throw UploadedRevisionCheckerError.blockUploadSizeIncorrect
                }

                blocks.append(block)
                index += 1
                data = try reader.read(upToCount: maxBlockSize) ?? Data()

                // A safeguard to ensure the next data read isn't empty when blocks are still expected
                guard !data.isEmpty || (data.isEmpty && index > expectedBlockSizes.count) else {
                    throw UploadedRevisionCheckerError.blockUploadSizeIncorrect
                }

                progress.complete(units: 1)
            }
        }

        return blocks
    }
    
    private func encryptBlocksInParallel(_ draft: CreatedRevisionDraft, encryptionMetadata: EncryptionMetadata, signersKit: SignersKit) async throws -> [UploadBlockMetadata] {
        // preparations
        let reader = try FileHandle(forReadingFrom: draft.localURL)
        defer { try? reader.close() }
        let expectedBlockSizes = draft.size.split(divisor: maxBlockSize)
        var blocks: [UploadBlockMetadata] = []
        
        let blocksPerJob = 1
        let numberOfConcurrentJobs = ProcessInfo.processInfo.activeProcessorCount
        let numberOfBlocksPerGroup = blocksPerJob * numberOfConcurrentJobs
        
        var index = 0
        var unencryptedBlocks: [(Data, Int)] = try (0..<numberOfBlocksPerGroup).compactMap { _ in
            guard let block = try reader.read(upToCount: maxBlockSize) else { return nil }
            index += 1 // BE starts numeration of blocks from 1
            self.digestBuilder.add(block)
            return (block, index)
        }
        
        while !unencryptedBlocks.isEmpty, !self.isCancelled {
            
            let encryptedBlocks = try await withThrowingTaskGroup(of: [UploadBlockMetadata].self) { group -> [UploadBlockMetadata] in
                
                let blocksBatches = unencryptedBlocks.splitInGroups(of: blocksPerJob)
                
                for batch in blocksBatches where !batch.isEmpty && !self.isCancelled {
                    
                    _ = group.addTaskUnlessCancelled {
                        
                        var encryptedBlocks: [UploadBlockMetadata] = []
                    
                        for (data, index) in batch where !data.isEmpty && !self.isCancelled {
                            
                            Log.info("STAGE: 1.2 Encrypting block \(index) 🚧, UUID: \(draft.uploadID)", domain: .uploader)
                            
                            let pack = NewBlockDataCleartext(index: index, cleardata: data)
                            let encryptedBlock = try Self.encryptBlock(pack, encryptionMetadata: encryptionMetadata)
                            let encSignature = try Self.encryptSignature(data, encryptionMetadata: encryptionMetadata, signersKit: signersKit)
                            let block = Self.createBlockMetadata(draft.volumeID, encSignature, signersKit.address.email, encryptedBlock, pack)
                            try Self.writeEncryptedData(encryptedBlock.cypherdata, for: block, localURLs: self.localURLs)
                            
                            // A safeguard to ensure the expected number of blocks read
                            guard block.clearSize == expectedBlockSizes[safe: index - 1] else {
                                throw UploadedRevisionCheckerError.blockUploadSizeIncorrect
                            }
                            
                            // A safeguard to ensure the next data read isn't empty when blocks are still expected
                            guard !data.isEmpty || (data.isEmpty && index > expectedBlockSizes.count) else {
                                throw UploadedRevisionCheckerError.blockUploadSizeIncorrect
                            }
                            
                            encryptedBlocks.append(block)
                        }
                        
                        return encryptedBlocks
                    }
                }
             
                var encryptedBlocks = [UploadBlockMetadata]()
                for try await encryptedBlock in group {
                    encryptedBlocks.append(contentsOf: encryptedBlock)
                }
                self.progress.complete(units: encryptedBlocks.count)
                return encryptedBlocks
            }
            
            blocks.append(contentsOf: encryptedBlocks)
            
            unencryptedBlocks = try (0..<numberOfBlocksPerGroup).compactMap { _ in
                guard let block = try reader.read(upToCount: maxBlockSize) else { return nil }
                index += 1
                self.digestBuilder.add(block)
                return (block, index)
            }
        }
        return blocks
    }

    private static func createBlockMetadata(_ volumeID: String, _ signature: String, _ signatureEmail: String, _ encrypted: NewBlockDataCyphertext, _ cleartext: NewBlockDataCleartext) -> UploadBlockMetadata {
        // we'll use these blocks later when we'll need to restore Operations
        return UploadBlockMetadata(
            volumeID: volumeID,
            localPath: UUID().uuidString,
            index: encrypted.index,
            sha256: encrypted.hash,
            size: encrypted.size,
            clearSize: cleartext.size,
            encSignature: signature,
            signatureEmail: signatureEmail
        )
    }

    private static func writeEncryptedData(_ data: Data, for block: UploadBlockMetadata, localURLs: Atomic<[URL]>) throws {
        let localUrl = PDFileManager.cypherBlocksCacheDirectory.appendingPathComponent(block.localPath)
        localURLs.mutate {
            $0.append(localUrl)
        }
        try data.write(to: localUrl)
    }

    private static func encryptBlock(_ block: NewBlockDataCleartext, encryptionMetadata: EncryptionMetadata) throws -> NewBlockDataCyphertext {
        let encrypted = try Encryptor.encryptBinary(chunk: block.cleardata,
                                                    contentKeyPacket: encryptionMetadata.contentKeyPacket,
                                                    nodeKey: encryptionMetadata.nodeKey,
                                                    nodePassphrase: encryptionMetadata.passphrase)
        return .init(index: block.index, cypherdata: encrypted.data, hash: encrypted.hash)
    }

    private static func encryptSignature(_ cleartextChunk: Data, encryptionMetadata: EncryptionMetadata, signersKit: SignersKit) throws -> String {
        let encSignature = try Encryptor.signcrypt(plaintext: cleartextChunk,
                                                   nodeKey: encryptionMetadata.nodeKey,
                                                   addressKey: signersKit.addressKey.privateKey,
                                                   addressPassphrase: signersKit.addressPassphrase)
        return encSignature
    }

    private func populateRevision(_ blocks: [UploadBlockMetadata], revision: Revision, signersKit: SignersKit) throws {
        guard !self.isCancelled else { throw BlockGenerationError.cancelled }

        var index = 0
        var revisionSize = 0
        while !self.isCancelled && index < blocks.count {
            autoreleasepool {
                let uploadBlock = createUploadBlock(with: blocks[index])
                revision.addToBlocks(uploadBlock)
                revisionSize += uploadBlock.size
                index += 1
            }
        }

        revision.size = revisionSize
        revision.signatureAddress = signersKit.address.email

        guard !self.isCancelled else { throw BlockGenerationError.cancelled }
    }

    private func createUploadBlock(with blockMetadata: UploadBlockMetadata) -> UploadBlock {
        let block = UploadBlock(context: self.moc)
        block.volumeID = blockMetadata.volumeID
        block.index = blockMetadata.index
        block.sha256 = blockMetadata.sha256
        block.size = blockMetadata.size
        block.clearSize = blockMetadata.clearSize
        block.encSignature = blockMetadata.encSignature
        block.signatureEmail = blockMetadata.signatureEmail
        block.localPath = blockMetadata.localPath
        return block
    }

    ///// Temporary holder for block cyphertext values
    struct NewBlockDataCyphertext {
        var index: Int
        var cypherdata: Data
        var hash: Data
        var size: Int { cypherdata.count }
    }

}

enum BlockGenerationError: String, LocalizedError {
    case noFileKeyPacket
    case cancelled
    
    public var errorDescription: String? {
        "Could not upload file: \(self.rawValue)"
    }
}
