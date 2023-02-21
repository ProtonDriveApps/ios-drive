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

extension Thumbnail {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Thumbnail> {
        return NSFetchRequest<Thumbnail>(entityName: "Thumbnail")
    }

    @NSManaged public var revision: Revision
    @NSManaged public var encrypted: Data?

    // MARK: - Download Thumbnail
    @NSManaged public var downloadURL: String?

    // MARK: - Upload Thumbnail - Use only in the context of uploading a Thumbnail
    @NSManaged public var uploadURL: String?
    @NSManaged public var sha256: Data?
    @NSManaged public var isUploaded: Bool

    // MARK: - Transient Properties
    @NSManaged internal var clearData: Data?
}

extension Thumbnail {
    static func make(downloadURL: URL?, revision: Revision, in moc: NSManagedObjectContext) -> Thumbnail {
        let thumbnail = Thumbnail(context: moc)
        thumbnail.downloadURL = downloadURL?.absoluteString
        thumbnail.revision = revision

        return thumbnail
    }
}
