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

final class PhotosThumbnailRevisionEncryptor: ThumbnailRevisionEncryptor {

    override func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
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

    override func encryptThrowing(_ draft: CreatedRevisionDraft) throws {
        let encryptionMetadata = try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { throw ThumbnailGenerationError.cancelled }
            let revision = draft.revision.in(moc: moc)
            return try getEncryptionMetadata(for: revision.file)
        }

        let encryptedThumbnails = try encryptThumbnails(draft, encryptionMetadata)

        guard !isCancelled else { throw ThumbnailGenerationError.cancelled }

        try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { throw ThumbnailGenerationError.cancelled }

            let revision = draft.revision.in(moc: moc)
            revision.removeOldThumbnails(in: moc)

            let thumbnails = Set(encryptedThumbnails.map { self.makeThumbnail(from: $0.data, type: $0.type) })
            revision.addToThumbnails(thumbnails)

            if isCancelled {
                self.moc.rollback()
            } else {
                try self.moc.saveOrRollback()
            }
        }
    }

    private func encryptThumbnails(_ draft: CreatedRevisionDraft, _ encryptionMetadata: EncryptionMetadata) throws -> [(data: EncryptedThumbnailData, type: ThumbnailType)] {
        let smallThumbnailData = try makeEncryptedThumbnailData(
            ofSize: Constants.defaultThumbnailMaxSize,
            maxWeight: Constants.thumbnailMaxWeight,
            encryptionMetadata: encryptionMetadata,
            localURL: draft.localURL
        )

        Log.info("STAGE: 1.1 🏞🏁 Encrypted thumbnail 1. UUID: \(draft.uploadID)", domain: .uploader)

        guard draft.mimetype.isImage else { return [(smallThumbnailData, .default)] }

        guard !isCancelled else { throw ThumbnailGenerationError.cancelled }

        let bigThumbnailData = try makeEncryptedThumbnailData(
            ofSize: Constants.photoThumbnailMaxSize,
            maxWeight: Constants.photoThumbnailMaxWeight,
            encryptionMetadata: encryptionMetadata,
            localURL: draft.localURL
        )

        Log.info("STAGE: 1.1 🏞🏁 Encrypted thumbnail 2. UUID: \(draft.uploadID)", domain: .uploader)

        return [(smallThumbnailData, .default), (bigThumbnailData, .photos)]
    }
}
