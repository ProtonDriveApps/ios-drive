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

public typealias CoreDataPhotoRevision = PhotoRevision

@objc(PhotoRevision)
public class PhotoRevision: Revision {
    @NSManaged public var exif: String
    @NSManaged public var transientClearExif: Data?
    @NSManaged public var contentHash: String?

    @NSManaged public var photo: Photo

    // MARK: Content digest

    public func getContentDigest() throws -> FileContentDigest {
        do {
            let attributes = try decryptedExtendedAttributes()
            let digest = try attributes.common?.digests?.sha1 ?! "Missing clear content hash"
            return .contentDigest(digest)
        } catch {
            let oldContentHash = try contentHash ?! "Missing revision's content hash"
            return .contentHash(oldContentHash)
        }
    }
}

public enum FileContentDigest {
    // Decrypted sha1, can be rehashed with new parent hash key when moving
    case contentDigest(String)
    // Sha1 hashed with the current parent hash key
    case contentHash(String)
}
