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
    typealias Errors = Uploader.Errors
    
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
        ConsoleLogger.shared?.log("STAGE: 1.2 Encrypt Revision 🏞📦📦 started", osLogType: FileUploader.self)

        moc.performAndWait {
            do {
                let revision = draft.revision.in(moc: self.moc)
                revision.removeOldBlocks(in: self.moc)
                guard let signatureAddress = revision.signatureAddress else { throw RevisionEncryptorError.noSignatureEmailInRevision }
                let signersKit = try signersKitFactory.make(forSigner: .address(signatureAddress))

                let uploadBlocks = try self.createEncryptedBlocks(draft.localURL, revision: revision, signersKit: signersKit)
                self.finalize(uploadBlocks, thumbnail: nil, revision: revision, cleanupCleartext: draft.localURL, signersKit: signersKit)
                ConsoleLogger.shared?.log("STAGE: 1.2 Encrypt Revision 🏞📦📦 finished ✅", osLogType: FileUploader.self)
                completion(.success(Void()))

            } catch {
                ConsoleLogger.shared?.log("STAGE: 1.2 Encrypt Revision 🏞📦📦 finished ❌", osLogType: FileUploader.self)
                moc.rollback()
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
    private func createEncryptedBlocks(_ cleartextlUrl: URL, revision: Revision, signersKit: SignersKit) throws -> [UploadBlock] {
        let cleartextBlockUrls = try FileManager.default.split(file: cleartextlUrl, maxBlockSize: maxBlockSize, chunkSize: Constants.maxBlockChunkSize)

        var iterator = cleartextBlockUrls.makeIterator()
        var uploadBlocks = [UploadBlock]()
        var index = 0

        while let blockURL = iterator.next() {
            index += 1
            ConsoleLogger.shared?.log("STAGE: 1.2 Encrypting block \(index) 🚧🚰", osLogType: FileUploader.self)
            try autoreleasepool {
                let pack = NewBlockUrlCleartext(index: index, cleardata: blockURL) // Cloud requires first index == 1
                let encryptedBlock = try self.encryptBlock(pack, file: revision.file)
                let encSignature = try self.encryptSignature(blockURL, file: revision.file, signersKit: signersKit)
                let block = try self.createNewBlock(encSignature, signersKit.address.email, encryptedBlock)
                _ = try block.store(cyphertext: encryptedBlock.cypherdata)
                try FileManager.default.removeItem(at: blockURL)
                uploadBlocks.append(block)
            }
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

    private func finalize(_ blocks: [UploadBlock], thumbnail: Thumbnail?, revision: Revision, cleanupCleartext cleartextlUrl: URL, signersKit: SignersKit) {
        do {
            if !self.isCancelled {
                blocks.forEach { $0.revision = revision }
                revision.size = blocks.map(\.size).reduce(0, +)
                revision.blocks = Set(blocks)
                revision.signatureAddress = signersKit.address.email
                revision.thumbnail = thumbnail
            } else {
                ConsoleLogger.shared?.log("🧹 Clear blocks - Operation cancelled ", osLogType: FileUploader.self)
                blocks.forEach(self.moc.delete)
                [revision.thumbnail].compactMap({ $0 }).forEach(self.moc.delete)
            }

            try self.moc.save()
        } catch {
            ConsoleLogger.shared?.log(error, osLogType: FileUploader.self)
            assert(false, error.localizedDescription)
        }
    }

    private func createNewBlock(_ signature: String, _ signatureEmail: String, _ encrypted: NewBlockUrlCyphertext) throws -> UploadBlock {
        UploadBlock.make(
            signature: signature,
            signatureEmail: signatureEmail,
            index: encrypted.index,
            hash: encrypted.hash,
            size: encrypted.size,
            moc: moc
        )
    }

}
