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

        ConsoleLogger.shared?.log("STAGE: 1.1 🏞 Encrypt thumbnail started", osLogType: FileUploader.self)
        moc.perform {
            do {
                let revision = draft.revision.in(moc: self.moc)
                guard let photoRevision = revision as? PhotoRevision else {
                    throw revision.invalidState("Should be a PhotoRevision.")
                }
                let smallThumbnail = try self.makeCoreDataThumbnail(ofSize: Constants.defaultThumbnailMaxSize, maxWeight: Constants.thumbnailMaxWeight, draft)
                smallThumbnail.type = .default
                photoRevision.addToThumbnails(smallThumbnail)

                let bigThumbnail = try self.makeCoreDataThumbnail(ofSize: Constants.photoThumbnailMaxSize, maxWeight: Constants.photoThumbnailMaxWeight, draft)
                bigThumbnail.type = .photos
                photoRevision.addToThumbnails(bigThumbnail)

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

}
