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
import CoreImage
import CoreData

class ThumbnailRevisionEncryptor: RevisionEncryptor {

   let thumbnailProvider: ThumbnailProvider
   let signersKitFactory: SignersKitFactoryProtocol
   let progress: Progress
   let moc: NSManagedObjectContext

   var isCancelled = false
   var isExecuting = false

    init(
        thumbnailProvider: ThumbnailProvider,
        signersKitFactory: SignersKitFactoryProtocol,
        progress: Progress,
        moc: NSManagedObjectContext
    ) {
        self.thumbnailProvider = thumbnailProvider
        self.signersKitFactory = signersKitFactory
        self.progress = progress
        self.moc = moc
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true

        Log.info("STAGE: 1.1 🏞 Encrypt thumbnail started. UUID: \(draft.uploadID)", domain: .uploader)
        do {
            try encryptThrowing(draft)
            Log.info("STAGE: 1.1 🏞 Encrypt thumbnail finished ✅. UUID: \(draft.uploadID)", domain: .uploader)
            self.progress.complete()
            completion(.success)
            
        } catch ThumbnailGenerationError.cancelled {
            return
        } catch {
            Log.info("STAGE: 1.1 🏞 Encrypt thumbnail finished ❌. UUID: \(draft.uploadID)", domain: .uploader)
            completion(.failure(error))
        }
    }
    
    func encryptThrowing(_ draft: CreatedRevisionDraft) throws {
        let encryptionMetadata = try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { throw ThumbnailGenerationError.cancelled }
            
            let revision = draft.revision.in(moc: moc)
            return try getEncryptionMetadata(for: revision.file)
        }
        
        let thumbnailData = try makeEncryptedThumbnailData(
            ofSize: Constants.defaultThumbnailMaxSize,
            maxWeight: Constants.thumbnailMaxWeight,
            encryptionMetadata: encryptionMetadata,
            localURL: draft.localURL
        )
        
        guard !isCancelled else { throw ThumbnailGenerationError.cancelled }
        
        Log.info("STAGE: 1.1 🏞🏁 Encrypted thumbnail 1. UUID: \(draft.uploadID)", domain: .uploader)
        
        try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { throw ThumbnailGenerationError.cancelled }
            
            let revision = draft.revision.in(moc: self.moc)
            revision.removeOldThumbnails(in: self.moc)
            
            let thumbnail = makeThumbnail(from: thumbnailData, type: .default, volumeID: draft.volumeID)
            revision.addToThumbnails(thumbnail)
            
            if self.isCancelled {
                self.moc.rollback()
                throw ThumbnailGenerationError.cancelled
            } else {
                try self.moc.saveOrRollback()
            }
        }
    }

    func cancel() {
        isCancelled = true
    }

    func getEncryptionMetadata(for file: File) throws -> EncryptionMetadata {
        guard let rawContentKeyPacket = file.contentKeyPacket,
              let contentKeyPacket = Data(base64Encoded: rawContentKeyPacket) else {
            throw ThumbnailGenerationError.noFileKeyPacket
        }
        guard let signatureEmail = file.signatureEmail else {
            throw ThumbnailGenerationError.noSignatureEmailInFile
        }
        let nodePassphrase = try file.decryptPassphrase()
#if os(macOS)
        // TODO: Conceptually it should we should use draft.revision.signatureAddress, in this case is the same because the creator of the file is the same as the creator of the revision, and both are created at the same time
        let signersKit = try signersKitFactory.make(forSigner: .address(signatureEmail))
#else
        let addressID = try file.getContextShareAddressID()
        let signersKit = try signersKitFactory.make(forAddressID: addressID)
#endif
        return EncryptionMetadata(
            nodeKey: file.nodeKey,
            contentKeyPacket: contentKeyPacket,
            passphrase: nodePassphrase,
            signatureEmail: signatureEmail,
            signersKit: signersKit
        )
    }

    func makeThumbnail(from thumbnailData: EncryptedThumbnailData, type: ThumbnailType, volumeID: String) -> Thumbnail {
        let coreDataThumbnail = Thumbnail(context: self.moc)
        coreDataThumbnail.encrypted = thumbnailData.encrypted
        coreDataThumbnail.sha256 = thumbnailData.hash
        coreDataThumbnail.type = type
        coreDataThumbnail.volumeID = volumeID
        return coreDataThumbnail
    }

    func makeEncryptedThumbnailData(ofSize size: CGSize, maxWeight: Int, encryptionMetadata: EncryptionMetadata, localURL: URL) throws -> EncryptedThumbnailData {
        guard let rawThumbnail = self.thumbnailProvider.getThumbnail(from: localURL, ofSize: size) else {
            throw ThumbnailGenerationError.generation
        }
        return try self.compressAndEncrypt(rawThumbnail, maxThumbnailWeight: maxWeight, encryptionMetadata: encryptionMetadata)
    }

    private func compressAndEncrypt(_ cgImage: CGImage, maxThumbnailWeight: Int, encryptionMetadata: EncryptionMetadata) throws -> EncryptedThumbnailData {
        for quality in [1.0, 0.7, 0.4, 0.2, 0.1, 0] {
            guard !isCancelled else {
                throw ThumbnailGenerationError.cancelled
            }
            guard let compressed = cgImage.jpegData(compressionQuality: quality) else {
                throw ThumbnailGenerationError.compression
            }

            guard compressed.count <= maxThumbnailWeight else { continue }

            guard !isCancelled else {
                throw ThumbnailGenerationError.cancelled
            }
            let encryptedThumbnail = try encrypt(compressed, encryptionMetadata: encryptionMetadata)

            if encryptedThumbnail.encrypted.count <= maxThumbnailWeight {
                return encryptedThumbnail
            }
        }

        throw ThumbnailGenerationError.invalidSizeThumbnail
    }

    func encrypt(_ thumbnail: Data, encryptionMetadata: EncryptionMetadata) throws -> EncryptedThumbnailData {
        let encryptedThumbnail = try encrypt(clearThumbnail: thumbnail, encryptionMetadata: encryptionMetadata)

        // MARK: - NEW
        return EncryptedThumbnailData(
            encrypted: encryptedThumbnail.data,
            hash: encryptedThumbnail.hash
        )
    }

    func encrypt(clearThumbnail thumbnail: Data, encryptionMetadata: EncryptionMetadata) throws -> Encryptor.EncryptedBinary {
        return try Encryptor.encryptAndSignBinary(
            clearData: thumbnail,
            contentKeyPacket: encryptionMetadata.contentKeyPacket,
            privateKey: encryptionMetadata.nodeKey,
            passphrase: encryptionMetadata.passphrase,
            addressKey: encryptionMetadata.signersKit.addressKey.privateKey,
            addressPassphrase: encryptionMetadata.signersKit.addressPassphrase
        )
    }
}

public enum ThumbnailGenerationError: String, LocalizedError {
    case noFileKeyPacket
    case generation
    case compression
    case cancelled
    case invalidSizeThumbnail
    case noSignatureEmailInFile
}
