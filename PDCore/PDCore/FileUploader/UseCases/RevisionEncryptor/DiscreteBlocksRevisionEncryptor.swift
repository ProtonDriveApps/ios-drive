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

final class DiscreteBlocksRevisionEncryptor: RevisionEncryptor {

    private let signersKitFactory: SignersKitFactoryProtocol
    private let maxBlockSize: Int
    private let progress: Progress
    private let moc: NSManagedObjectContext

    private var isCancelled = false
    private var isExecuting = false

    init(
        signersKitFactory: SignersKitFactoryProtocol,
        maxBlockSize: Int,
        progress: Progress,
        moc: NSManagedObjectContext
    ) {
        self.signersKitFactory = signersKitFactory
        self.maxBlockSize = maxBlockSize
        self.progress = progress
        self.moc = moc
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true

        ConsoleLogger.shared?.log("STAGE: 1.2 Encrypt blocks 📦📦 started", osLogType: FileUploader.self)

        moc.perform {
            do {
                let revision = draft.revision.in(moc: self.moc)
                revision.removeOldBlocks(in: self.moc)
                let signersKit = try self.getSignersKit(for: revision)
                let uploadBlocks = try self.createEncryptedBlocks(draft.localURL, revision: revision, signersKit: signersKit)
                self.finalize(uploadBlocks, revision: revision, cleanupCleartext: draft.localURL, signersKit: signersKit)

                try self.moc.saveOrRollback()

                ConsoleLogger.shared?.log("STAGE: 1.2 Encrypt blocks 📦📦 finished ✅", osLogType: FileUploader.self)

                self.progress.complete()
                completion(.success)

            } catch {
                ConsoleLogger.shared?.log("STAGE: 1.2 Encrypt blocks 📦📦 finished ❌", osLogType: FileUploader.self)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
    }
}

extension DiscreteBlocksRevisionEncryptor {

    private func getSignersKit(for revision: Revision) throws -> SignersKit {
        guard let signatureAddress = revision.signatureAddress else {
            throw RevisionEncryptorError.noSignatureEmailInRevision
        }
        return try signersKitFactory.make(forSigner: .address(signatureAddress))
    }

    /// Breaks cleartext file into a number of Blocks
    private func createEncryptedBlocks(_ cleartextlUrl: URL, revision: Revision, signersKit: SignersKit) throws -> [UploadBlock] {
        // preparations
        let reader = try FileHandle(forReadingFrom: cleartextlUrl)
        defer { reader.closeFile() }
        var blocks: [UploadBlock] = []

        // Blocks
        var index = 1 // BE starts numeration of blocks from 1
        var data = reader.readData(ofLength: maxBlockSize)
        while !data.isEmpty, !self.isCancelled {
            ConsoleLogger.shared?.log("STAGE: 1.2 Encrypting block \(index) 🚧", osLogType: FileUploader.self)
            try autoreleasepool {

                let pack = NewBlockDataCleartext(index: index, cleardata: data)
                let encryptedBlock = try encryptBlock(pack, file: revision.file)
                let encSignature = try encryptSignature(data, file: revision.file, signersKit: signersKit)
                let block = try createNewBlock(encSignature, signersKit.address.email, encryptedBlock)
                _ = try block.store(cyphertext: encryptedBlock.cypherdata)

                blocks.append(block)
                index += 1
                data = reader.readData(ofLength: maxBlockSize)

                progress.complete(1)
            }
        }

        return blocks
    }

    private func createNewBlock(_ signature: String, _ signatureEmail: String, _ encrypted: NewBlockDataCyphertext) throws -> UploadBlock {
        // we'll use these blocks later when we'll need to restore Operations
        let block = UploadBlock(context: self.moc)
        block.index = encrypted.index
        block.sha256 = encrypted.hash
        block.size = encrypted.size
        block.encSignature = signature
        block.signatureEmail = signatureEmail
        return block
    }

    func encryptBlock(_ block: NewBlockDataCleartext, file: File) throws -> NewBlockDataCyphertext {
        guard let rawContentKeyPacket = file.contentKeyPacket,
              let contentKeyPacket = Data(base64Encoded: rawContentKeyPacket) else
        {
            throw Uploader.Errors.noFileKeyPacket
        }
        let nodePassphrase = try file.decryptPassphrase()

        // TODO: Try to reuse the session key to make the process more performant
        let encrypted = try Encryptor.encryptBinary(chunk: block.cleardata,
                                                    contentKeyPacket: contentKeyPacket,
                                                    nodeKey: file.nodeKey,
                                                    nodePassphrase: nodePassphrase)
        return .init(index: block.index, cypherdata: encrypted.data, hash: encrypted.hash)
    }

    func encryptSignature(_ cleartextChunk: Data, file: File, signersKit: SignersKit) throws -> String {
        let encSignature = try Encryptor.signcrypt(plaintext: cleartextChunk,
                                                   nodeKey: file.nodeKey,
                                                   addressKey: signersKit.addressKey.privateKey,
                                                   addressPassphrase: signersKit.addressPassphrase)
        return encSignature
    }

    func finalize(_ blocks: [UploadBlock], revision: Revision, cleanupCleartext cleartextlUrl: URL, signersKit: SignersKit) {
        if isCancelled {
            blocks.forEach(moc.delete)
        } else {
            blocks.forEach { $0.revision = revision }
            revision.size = blocks.map(\.size).reduce(0, +)
            revision.blocks = Set(blocks)
            revision.signatureAddress = signersKit.address.email
        }
    }

    ///// Temporary holder for block cyphertext values
    struct NewBlockDataCyphertext {
        var index: Int
        var cypherdata: Data
        var hash: Data
        var size: Int { cypherdata.count }
    }

}
