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

        ConsoleLogger.shared?.log("STAGE: 1.1 🏞 Encrypt thumbnail started", osLogType: FileUploader.self)
        moc.perform {
            do {
                let revision = draft.revision.in(moc: self.moc)
                revision.removeOldThumbnails(in: self.moc)
                let thumbnail = try self.makeCoreDataThumbnail(ofSize: Constants.defaultThumbnailMaxSize, maxWeight: Constants.thumbnailMaxWeight, draft)
                revision.addToThumbnails(thumbnail)

                try self.moc.saveOrRollback()
                
                ConsoleLogger.shared?.log("STAGE: 1.1 🏞 Encrypt thumbnail finished ✅", osLogType: FileUploader.self)

                self.progress.complete()
                completion(.success)

            } catch {
                ConsoleLogger.shared?.log("STAGE: 1.1 🏞 Encrypt thumbnail finished ❌", osLogType: FileUploader.self)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        isCancelled = true
    }

    func makeCoreDataThumbnail(ofSize size: CGSize, maxWeight: Int, _ draft: CreatedRevisionDraft) throws -> Thumbnail {
        guard let rawThumbnail = self.thumbnailProvider.getThumbnail(from: draft.localURL, ofSize: size) else {
            throw ThumbnailGenerationError.generation
        }
        let thumbnail = try self.compressAndEncrypt(rawThumbnail, maxThumbnailWeight: maxWeight, draft: draft)
        let coreDataThumbnail = Thumbnail(context: self.moc)
        coreDataThumbnail.encrypted = thumbnail.encrypted
        coreDataThumbnail.sha256 = thumbnail.hash
        return coreDataThumbnail
    }

    func compressAndEncrypt(_ cgImage: CGImage, maxThumbnailWeight: Int, draft: CreatedRevisionDraft) throws -> EncryptedThumbnailData {
        for quality in [1.0, 0.7, 0.4, 0.2, 0.1, 0] {
            guard let compressed = cgImage.jpegData(compressionQuality: quality) else {
                throw ThumbnailGenerationError.compression
            }

            guard compressed.count <= maxThumbnailWeight else { continue }

            let encryptedThumbnail = try encrypt(compressed, draft: draft)

            if encryptedThumbnail.encrypted.count <= maxThumbnailWeight {
                return encryptedThumbnail
            }
        }

        throw UploaderErrors.invalidSizeThumbnail
    }

    func encrypt(_ thumbnail: Data, draft: CreatedRevisionDraft) throws -> EncryptedThumbnailData {
        let moc = draft.revision.managedObjectContext!

        let uploadableThumbnailData: EncryptedThumbnailData = try moc.performAndWait {
            let encryptedThumbnail = try encrypt(clearThumbnail: thumbnail, for: draft.revision.file)

            // MARK: - NEW
            return EncryptedThumbnailData(
                encrypted: encryptedThumbnail.data,
                hash: encryptedThumbnail.hash
            )
        }

        return uploadableThumbnailData
    }

    func encrypt(clearThumbnail thumbnail: Data, for file: File) throws -> Encryptor.EncryptedBinary {
        guard let rawContentKeyPacket = file.contentKeyPacket,
              let contentKeyPacket = Data(base64Encoded: rawContentKeyPacket) else {
                  throw UploaderErrors.noFileKeyPacket
        }

        let nodePassphrase = try file.decryptPassphrase()
        // TODO: Conceptually it should we should use draft.revision.signatureAddress, in this case is the same because the creator of the file is the same as the creator of the revision, and both are created at the same time
        let signersKit = try signersKitFactory.make(forSigner: .address(file.signatureEmail))

        return try Encryptor.encryptAndSignBinary(
            clearData: thumbnail,
            contentKeyPacket: contentKeyPacket,
            privateKey: file.nodeKey,
            passphrase: nodePassphrase,
            addressKey: signersKit.addressKey.privateKey,
            addressPassphrase: signersKit.addressPassphrase
        )
    }
}

enum ThumbnailGenerationError: Error {
    case generation
    case compression
}
