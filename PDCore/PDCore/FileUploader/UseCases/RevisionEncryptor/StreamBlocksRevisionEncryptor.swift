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
import Foundation

final class StreamRevisionEncryptor: RevisionEncryptor {
    typealias Errors = UploaderErrors
    
    let signersKitFactory: SignersKitFactoryProtocol
    let maxBlockSize: Int
    let moc: NSManagedObjectContext
    private let digestBuilder: DigestBuilder

    private var isCancelled = false
    private var isExecuting = false

    init( signersKitFactory: SignersKitFactoryProtocol, maxBlockSize: Int, moc: NSManagedObjectContext, digestBuilder: DigestBuilder) {
        self.signersKitFactory = signersKitFactory
        self.maxBlockSize = maxBlockSize
        self.moc = moc
        self.digestBuilder = digestBuilder
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true
        Log.info("STAGE: 1.2 Encrypt Revision 🏞📦📦 started", domain: .uploader)

        moc.performAndWait {
            do {
                let revision = draft.revision.in(moc: self.moc)
                revision.removeOldBlocks(in: self.moc)
                guard let signatureAddress = revision.signatureAddress else { throw RevisionEncryptorError.noSignatureEmailInRevision }
                let signersKit = try signersKitFactory.make(forSigner: .address(signatureAddress))

                let uploadBlocks = try self.createEncryptedBlocks(draft, revision: revision, signersKit: signersKit)
                try self.finalize(uploadBlocks, revision: revision, cleanupCleartext: draft.localURL, signersKit: signersKit, id: draft.uploadID)

                try self.moc.saveOrRollback()
                Log.info("STAGE: 1.2 Encrypt Revision 🏞📦📦 finished ✅", domain: .uploader)
                completion(.success)
            } catch {
                Log.info("STAGE: 1.2 Encrypt Revision 🏞📦📦 finished ❌", domain: .uploader)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
    }
}

extension StreamRevisionEncryptor {

    /// Breaks cleartext file into a number of Blocks
    private func createEncryptedBlocks(_ draft: CreatedRevisionDraft, revision: Revision, signersKit: SignersKit) throws -> [UploadBlock] {
        assert(maxBlockSize % Constants.maxBlockChunkSize == 0, "The chunk should be divider without remainder. Otherwise block sizes in committer and xAttr encryptor need to be aligned")
        let expectedBlockSizes = draft.size.split(divisor: maxBlockSize)

        let cleartextBlockUrls = try FileManager.default.split(file: draft.localURL, maxBlockSize: maxBlockSize, chunkSize: Constants.maxBlockChunkSize)

        var iterator = cleartextBlockUrls.makeIterator()
        var uploadBlocks = [UploadBlock]()
        var index = 0

        while let blockURL = iterator.next() {
            index += 1
            Log.info("STAGE: 1.2 Encrypting block \(index) 🚧🚰. UUID: \(draft.uploadID)", domain: .uploader)
            try autoreleasepool {
                let pack = NewBlockUrlCleartext(index: index, cleardata: blockURL) // Cloud requires first index == 1
                let encryptedBlock = try self.encryptBlock(pack, file: revision.file)
                let encSignature = try self.encryptSignature(blockURL, file: revision.file, signersKit: signersKit)
                let block = try self.createNewBlock(encSignature, signersKit.address.email, encryptedBlock, pack)
                _ = try block.store(cyphertext: encryptedBlock.cypherdata)
                try FileManager.default.removeItem(at: blockURL)

                // A safeguard to ensure the expected number of blocks read
                guard block.clearSize == expectedBlockSizes[index - 1] else {
                    throw UploadedRevisionCheckerError.blockUploadSizeIncorrect
                }

                uploadBlocks.append(block)
            }
        }

        // A safeguard to ensure no blocks were missed
        guard uploadBlocks.count == expectedBlockSizes.count else {
            throw UploadedRevisionCheckerError.blockUploadCountIncorrect
        }

        return uploadBlocks
    }

    private func encryptBlock(_ block: NewBlockUrlCleartext, file: File) throws -> NewBlockUrlCyphertext {
        guard let rawContentKeyPacket = file.contentKeyPacket,
              let contentKeyPacket = Data(base64Encoded: rawContentKeyPacket) else
        {
            throw Errors.noFileKeyPacket
        }
        let nodePassphrase = try file.decryptPassphrase()
        let cleartextUrl = block.cleardata
        let cyphertextUrl = cleartextUrl.appendingPathExtension("\(block.index)")

        let hash = try Encryptor.encryptStream(cleartextUrl, cyphertextUrl, file.nodeKey, nodePassphrase, contentKeyPacket, digestBuilder)
        let size = try FileManager.default.attributesOfItem(atPath: cyphertextUrl.path)[.size] as! UInt64

        return .init(index: block.index, cypherdata: cyphertextUrl, hash: hash, size: Int(size))
    }

    private func encryptSignature(_ cleartextUrl: URL, file: File, signersKit: SignersKit) throws -> String {
        let encSignature = try Encryptor.signStream(file.nodeKey, signersKit.addressKey.privateKey, signersKit.addressPassphrase, cleartextUrl)
        return encSignature
    }

    private func finalize(_ blocks: [UploadBlock], revision: Revision, cleanupCleartext cleartextlUrl: URL, signersKit: SignersKit, id: UUID) throws {
        if !self.isCancelled {
            blocks.forEach { $0.revision = revision }
            revision.size = blocks.map(\.size).reduce(0, +)
            revision.blocks = Set(blocks)
            revision.signatureAddress = signersKit.address.email
        } else {
            Log.info("STAGE: 1.2 🧹 Clear blocks - Operation cancelled. UUID: \(id)", domain: .uploader)
            blocks.forEach(self.moc.delete)
        }
    }

    private func createNewBlock(_ signature: String, _ signatureEmail: String, _ encrypted: NewBlockUrlCyphertext, _ cleartext: NewBlockUrlCleartext) throws -> UploadBlock {
        guard let clearSize = cleartext.size else {
            throw URLConsistencyError.noURLSize
        }

        return UploadBlock.make(
            signature: signature,
            signatureEmail: signatureEmail,
            index: encrypted.index,
            hash: encrypted.hash,
            size: encrypted.size,
            clearSize: clearSize,
            moc: moc
        )
    }

}
