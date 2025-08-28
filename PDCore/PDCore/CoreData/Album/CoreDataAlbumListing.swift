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

@objc(CoreDataAlbumListing)
public class CoreDataAlbumListing: NSManagedObject, VolumeUnique {

    // MARK: Properties

    @NSManaged public var id: String // `LinkID` on BE
    @NSManaged public var volumeID: String
    @NSManaged public var shareID: String?
    @NSManaged public var locked: Bool
    @NSManaged public var coverLinkID: String?
    @NSManaged public var lastActivityTime: Date
    @NSManaged public var photoCount: Int16
    /// When listing object is created, DB should be queried to find out if we have Album metadata already and wire it up.
    @NSManaged public var album: CoreDataAlbum?
    @NSManaged public var photos: Set<CoreDataPhotoListing>

    public var albumIdentifier: AlbumIdentifier {
        return AlbumIdentifier(id: id, volumeID: volumeID)
    }

    // MARK: Request

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CoreDataAlbumListing> {
        return NSFetchRequest<CoreDataAlbumListing>(entityName: "CoreDataAlbumListing")
    }

    // MARK: Generated accessors

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: CoreDataPhotoListing)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: CoreDataPhotoListing)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: Set<CoreDataPhotoListing>)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: Set<CoreDataPhotoListing>)
}
