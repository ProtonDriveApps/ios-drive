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

extension Thumbnail: VolumeUnique {
    @NSManaged public var id: String
    @NSManaged public var volumeID: String
    @NSManaged public var revision: Revision
    @NSManaged public var type: ThumbnailType
    @available(*, deprecated, message: "Please use the sha256 property")
    @NSManaged private var thumbnailHash: String?

    @NSManaged private(set) var blob: ThumbnailBlob?

    // MARK: - Download Thumbnail
    @NSManaged public var downloadURL: String?

    // MARK: - Upload Thumbnail - Use only in the context of uploading a Thumbnail
    @NSManaged public var uploadURL: String?
    @NSManaged public var sha256: Data?
    @NSManaged public var isUploaded: Bool
    
    public var encrypted: Data? {
        get {
            blob?.encrypted
        }
        set {
            makeBlobIfNeeded()
            blob?.encrypted = newValue
        }
    }
    
    public var clearData: Data? {
        get {
            blob?.clearData
        }
        set {
            makeBlobIfNeeded()
            blob?.clearData = newValue
        }
    }

    public func clearBlob(in context: NSManagedObjectContext?, shouldSave: Bool = false) throws {
        guard
            let context = context ?? managedObjectContext,
            let blob
        else { return }
        try context.performAndWait {
            context.delete(blob)
            self.blob = nil
            if shouldSave {
                try context.saveIfNeeded()
            }
        }
    }

    private func makeBlobIfNeeded() {
        guard blob == nil, let moc = self.managedObjectContext else {
            return
        }
        blob = ThumbnailBlob(context: moc)
    }
}

extension Thumbnail {
    static func make(id: String, downloadURL: URL?, revision: Revision, type: ThumbnailType, hash: String, in moc: NSManagedObjectContext) -> Thumbnail {
        let thumbnail = Thumbnail(context: moc)
        thumbnail.id = id
        thumbnail.downloadURL = downloadURL?.absoluteString
        thumbnail.type = type
        thumbnail.sha256 = Data(base64Encoded: hash)
        revision.addToThumbnails(thumbnail)
        return thumbnail
    }
}

@objc public enum ThumbnailType: Int16, Equatable, Comparable {
    case `default` = 1
    case photos = 2
    
    public static func < (lhs: ThumbnailType, rhs: ThumbnailType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
