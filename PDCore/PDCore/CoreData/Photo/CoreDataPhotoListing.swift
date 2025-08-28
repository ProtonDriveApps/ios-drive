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

@objc(CoreDataPhotoListing)
public class CoreDataPhotoListing: NSManagedObject, VolumeParentUnique {

    // MARK: Properties

    @NSManaged public var id: String // `LinkID` on BE
    @NSManaged public var albumID: String? // Filled for photos inside albums, nil for photo stream
    @NSManaged public var volumeID: String
    @NSManaged public var captureTime: Date
    @NSManaged public var contentHash: String
    @NSManaged public var nameHash: String?
    @NSManaged public var addedTime: Date?
    // Tags are serialized into a single String to allow usage in fetch requests
    // Use together with `CoreDataPhotoTagSerializer`
    @NSManaged public var tagsRaw: String?
    @NSManaged public var album: CoreDataAlbumListing? // Filled for album photos, nil for photo stream
    @NSManaged public var relatedPhotos: Set<CoreDataPhotoListing>
    @NSManaged public var primaryPhoto: CoreDataPhotoListing?
    @NSManaged public var photo: Photo?

    // MARK: VolumeParentUnique

    public var parentID: String? {
        albumID
    }

    public static var parentIDKeyPath: String {
        return #keyPath(CoreDataPhotoListing.albumID)
    }

    // MARK: Identifier

    public var photoIdentifier: AnyVolumeIdentifier {
        AnyVolumeIdentifier(id: id, volumeID: volumeID)
    }

    // MARK: Tags

    public static let tagsSerializer = CoreDataPhotoTagSerializer()

    // MARK: Section identifier

    // Transient
    @objc public var monthIdentifier: String? {
        guard !isDeleted else {
            return nil
        }
        willAccessValue(forKey: "monthIdentifier")
        var cachedIdentifier = primitiveValue(forKey: "monthIdentifier") as? String
        didAccessValue(forKey: "monthIdentifier")

        if cachedIdentifier == nil {
            let calendar = CoreDataPhotoListing.calendar
            let components = calendar.dateComponents([.year, .month], from: captureTime)
            let year = components.year ?? 0
            let month = components.month ?? 0
            cachedIdentifier = "\(year) \(month)"
            setPrimitiveValue(cachedIdentifier, forKey: "monthIdentifier")
        }
        return cachedIdentifier
    }
    private static let calendar = Calendar.current

    // MARK: Request

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CoreDataPhotoListing> {
        return NSFetchRequest<CoreDataPhotoListing>(entityName: "CoreDataPhotoListing")
    }

    // MARK: Generated accessors

    @objc(addRelatedPhotosObject:)
    @NSManaged public func addToRelatedPhotos(_ value: CoreDataPhotoListing)

    @objc(removeRelatedPhotosObject:)
    @NSManaged public func removeFromRelatedPhotos(_ value: CoreDataPhotoListing)

    @objc(addRelatedPhotos:)
    @NSManaged public func addToRelatedPhotos(_ values: Set<CoreDataPhotoListing>)

    @objc(removeRelatedPhotos:)
    @NSManaged public func removeFromRelatedPhotos(_ values: Set<CoreDataPhotoListing>)
}
