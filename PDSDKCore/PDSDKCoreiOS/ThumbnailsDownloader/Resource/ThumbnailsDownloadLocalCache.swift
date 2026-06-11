// Copyright (c) 2025 Proton AG
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
import ProtonDriveSDK
import PDCore

protocol ThumbnailsDownloadLocalCacheProtocol {
    func storeThumbnails(_ thumbnails: [ThumbnailDataWithId], type: ThumbnailType) async throws
}

final class ThumbnailsDownloadLocalCache: ThumbnailsDownloadLocalCacheProtocol, Sendable {
    private let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func storeThumbnails(_ thumbnails: [ThumbnailDataWithId], type: ThumbnailType) async throws {
        try await managedObjectContext.perform { [managedObjectContext] in
            for thumbnailData in thumbnails {
                let identifier = AnyVolumeIdentifier(id: thumbnailData.fileUid.nodeID, volumeID: thumbnailData.fileUid.volumeID)
                guard let file: File = File.fetch(identifier: identifier, allowSubclasses: true, in: managedObjectContext) else {
                    Log.warning("Skipping CDthumbnail save for \(identifier.debugDesc) because the CoreDataFile is missing", domain: .sdk)
                    continue
                }
                guard let revision = file.activeRevision else {
                    Log.warning("Skipping CDthumbnail save for \(identifier.debugDesc) because the active revision is missing", domain: .sdk)
                    continue
                }
                self.createCoreDataThumbnailIfNecessary(revision: revision, thumbnailData: thumbnailData, type: type)
            }
            try self.managedObjectContext.saveOrRollback()
        }
        await thumbnails.forEach {
            await storeThumbnailToDisk($0, type: type)
        }
    }

    private func createCoreDataThumbnailIfNecessary(revision: CoreDataRevision, thumbnailData: ThumbnailDataWithId, type: ThumbnailType) {
        let isThumbnailPresent = revision.thumbnails.contains(where: { $0.type == type })
        guard !isThumbnailPresent else {
            Log.warning("Skipping CDthumbnail save for \(thumbnailData.fileUid.any.debugDesc) because thumbnail type \(type) already exists", domain: .sdk)
            return
        }
        let coreDataThumbnail = Thumbnail(context: managedObjectContext)
        coreDataThumbnail.type = type
        coreDataThumbnail.volumeID = thumbnailData.fileUid.volumeID
        coreDataThumbnail.revision = revision
    }

    private func storeThumbnailToDisk(_ thumbnailData: ThumbnailDataWithId, type: ThumbnailType) async {
        #if os(iOS)
        if case .success(let data) = thumbnailData.result {
            await CoreDataThumbnail.saveClearDataToDisk(
                clearData: data,
                type: type,
                identifier: NodeIdentifier(thumbnailData.fileUid.nodeID, "", thumbnailData.fileUid.volumeID)
            )
        }
        #endif
    }
}
