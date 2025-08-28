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

@objc(CoreDataAlbum)
public class CoreDataAlbum: Node, NodeWithNodeHashKeyProtocol {

    // MARK: Properties

    @NSManaged public var locked: Bool
    @NSManaged public var coverLinkID: String?
    @NSManaged public var lastActivityTime: Date
    @NSManaged public var nodeHashKey: String? // Optional to conform with `NodeWithNodeHashKey`
    @NSManaged public var photoCount: Int16
    @NSManaged public var coverPhoto: Photo?
    @NSManaged public var photos: Set<Photo>
    @NSManaged public var xAttributes: String?
    /// Relationship to lightweight listing object.
    /// When Album is deleted, nothing special needed: cascade delete rule is set up to delete listing.
    /// When Album is created, listings should be checked and wired up in case there's already such listing.
    @NSManaged public var albumListing: CoreDataAlbumListing?

    var albumIdentifier: AlbumIdentifier {
        return AlbumIdentifier(id: id, volumeID: volumeID)
    }

    // MARK: Request

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CoreDataAlbum> {
        return NSFetchRequest<CoreDataAlbum>(entityName: "CoreDataAlbum")
    }

    public static let mimeType = "Album"

    // MARK: Generated accessors

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: Photo)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: Photo)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: Set<Photo>)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: Set<Photo>)
}
