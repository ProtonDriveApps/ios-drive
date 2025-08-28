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
//

import CoreData

public typealias CoreDataPhoto = Photo

@objc(Photo)
public class Photo: File {
    @NSManaged public var captureTime: Date

    @NSManaged public var parent: Photo?
    @NSManaged public var children: Set<Photo>

    @NSManaged public var photoRevision: PhotoRevision

    @NSManaged public var albums: Set<CoreDataAlbum>
    @NSManaged public var photoListings: Set<CoreDataPhotoListing> // A photo can be listed in multiple albums

    // MainKey encrypted properties
    @NSManaged public var tempBase64Metadata: String?
    @NSManaged public var tempBase64Exif: String?
    @NSManaged public var tags: [Int]?

    // Deprecated
    @available(*, deprecated, message: "Not needed")
    @NSManaged override public var revisions: Set<Revision>

    @available(*, deprecated, message: "Not needed")
    @NSManaged override public var activeRevision: Revision?

    override public var parentNode: NodeWithNodeHashKey? {
        return parentFolder ?? albums.first
    }

    // Transient
    @objc public var monthIdentifier: String? {
        guard !isDeleted else {
            return nil
        }
        willAccessValue(forKey: "monthIdentifier")
        var cachedIdentifier = primitiveValue(forKey: "monthIdentifier") as? String
        didAccessValue(forKey: "monthIdentifier")

        if cachedIdentifier == nil {
            let calendar = Photo.calendar
            let components = calendar.dateComponents([.year, .month], from: captureTime)
            let year = components.year ?? 0
            let month = components.month ?? 0
            cachedIdentifier = "\(year) \(month)"
            setPrimitiveValue(cachedIdentifier, forKey: "monthIdentifier")
        }
        return cachedIdentifier
    }
    private static let calendar = Calendar.current
    
    func iCloudID() -> String? {
        return moc?.performAndWait {
            if let meta = tempBase64Metadata {
                return TemporalMetadata(base64String: meta)?.iOSPhotos.iCloudID
            } else {
                return activeRevisionDraft?.clearXAttributes?.iOSPhotos?.iCloudID
            }
        }
    }

    public func iOSPhotos() -> PhotoAssetMetadata.iOSPhotos? {
        let iOSPhotos = moc?.performAndWait {
            if let meta = tempBase64Metadata {
                return TemporalMetadata(base64String: meta)?.iOSPhotos
            } else {
                return try? photoRevision.unsafeDecryptedExtendedAttributes().iOSPhotos
            }
        }
        guard let iOSPhotos = iOSPhotos, let iCloudID = iOSPhotos.iCloudID else {
            return nil
        }
        let modificationTime = ISO8601DateFormatter().date(iOSPhotos.modificationTime)
        return PhotoAssetMetadata.iOSPhotos(identifier: iCloudID, modificationTime: modificationTime)
    }
    
    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Photo)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Photo)

    @objc(addChildren:)
    @NSManaged public func addToRevisions(_ values: Set<Photo>)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: Set<Photo>)

    @objc(addAlbumsObject:)
    @NSManaged public func addToAlbums(_ value: CoreDataAlbum)

    @objc(removeAlbumsObject:)
    @NSManaged public func removeFromAlbums(_ value: CoreDataAlbum)

    @objc(addAlbums:)
    @NSManaged public func addToAlbums(_ values: Set<CoreDataAlbum>)

    @objc(removeAlbums:)
    @NSManaged public func removeFromAlbums(_ values: Set<CoreDataAlbum>)

    @objc(addPhotoListingsObject:)
    @NSManaged public func addToPhotoListings(_ value: CoreDataPhotoListing)

    @objc(removePhotoListingsObject:)
    @NSManaged public func removeFromPhotoListings(_ value: CoreDataPhotoListing)

    @objc(addPhotoListings:)
    @NSManaged public func addToPhotoListings(_ values: Set<CoreDataPhotoListing>)

    @objc(removePhotoListings:)
    @NSManaged public func removeFromPhotoListings(_ values: Set<CoreDataPhotoListing>)

    // MARK: Fetch request

    @nonobjc public class func photoFetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }
}

// MARK: - PDCore DTO's for saving metadata and exif

public struct TemporalMetadata: Codable {
    public let location: ExtendedAttributes.Location?
    public let camera: ExtendedAttributes.Camera?
    public let media: ExtendedAttributes.Media
    public let iOSPhotos: ExtendedAttributes.iOSPhotos

    public init(metadata: PhotoAssetMetadata) {
        let formatter = ISO8601DateFormatter()
        self.location = metadata.location.map { ExtendedAttributes.Location(latitude: $0.latitude, longitude: $0.longitude) }
        self.camera = ExtendedAttributes.Camera(
            captureTime: formatter.string(metadata.camera.captureTime),
            device: metadata.camera.device,
            orientation: metadata.camera.orientation,
            subjectCoordinates: ExtendedAttributes.SubjectCoordinates(subjectCoordinates: metadata.camera.subjectCoordinates)
        )
        self.media = ExtendedAttributes.Media(width: metadata.media.width, height: metadata.media.height, duration: metadata.media.duration)
        self.iOSPhotos = ExtendedAttributes.iOSPhotos(iCloudID: metadata.iOSPhotos.identifier, modificationTime: formatter.string(metadata.iOSPhotos.modificationTime))
    }

    func base64Encoded() -> String? {
        try? JSONEncoder().encode(self).base64EncodedString()
    }
}

public extension TemporalMetadata {
    init?(base64String: String?) {
        guard let base64String,
              let data = Data(base64Encoded: base64String),
              let metadata = try? JSONDecoder().decode(TemporalMetadata.self, from: data) else {
            return nil
        }
        self = metadata
    }
}

extension Photo {
    /// There is no solid way to check given content is live photo or not
    /// If the childrenURLs has only one video URL
    /// The given content has chance to be a live photo
    public var canBeLivePhoto: Bool {
        guard let context = managedObjectContext else { return false }
        return context.performAndWait {
            let mainMime = MimeType(value: mimeType)
            let childrenMime = nonDuplicatedChildren.map { MimeType(value: $0.mimeType) }

            return mainMime.isImage && childrenMime.count == 1 && (childrenMime.first?.isVideo ?? false)
        }
    }

    /// workaround to fix duplicated upload
    /// sometimes a file can be uploaded twice
    public var nonDuplicatedChildren: [Photo] {
        guard let context = managedObjectContext else { return [] }
        return context.performAndWait {
            var names: [String] = []
            var nonDuplicatedChildren: [Photo] = []
            for child in children {
                let decryptedName = child.decryptedName
                if names.contains(decryptedName) { continue }
                names.append(decryptedName)
                nonDuplicatedChildren.append(child)
            }
            return nonDuplicatedChildren
        }
    }

    /// There is no solid way to check given content is burst photo or not
    /// If all of children are photos
    /// It is considered a burst photo.
    public var canBeBurstPhoto: Bool {
        guard let context = managedObjectContext else { return false }
        return context.performAndWait {
            let mainMime = MimeType(value: mimeType)
            let allChildrenArePhoto = children
                .map { MimeType(value: $0.mimeType) }
                .allSatisfy { $0.isImage }
            return mainMime.isImage && !children.isEmpty && allChildrenArePhoto
        }
    }

    public var isVideo: Bool {
        return MimeType(value: mimeType).isVideo
    }

    public func hasPhotoStreamListing() -> Bool {
        photoListings.contains(where: { $0.albumID == nil })
    }

    public var isRawPhoto: Bool {
        let mime = MimeType(value: mimeType).value.lowercased()
        let fileExtension = (decryptedName as NSString).pathExtension.lowercased()

        let knownRawMimeTypes: Set<String> = [
            "image/x-dcraw", "image/x-adobe-dng", "image/x-canon-crw", "image/x-canon-cr2", "image/x-canon-cr3",
            "image/x-epson-erf", "image/x-hasselblad-fff", "image/x-fuji-raf", "image/x-kodak-dcr", "image/x-kodak-k25",
            "image/x-kodak-kdc", "image/x-leaf-mos", "image/x-minolta-mrw", "image/x-nikon-nef", "image/x-nikon-nrw",
            "image/x-olympus-orf", "image/x-panasonic-raw", "image/x-raw", "image/x-panasonic-rw2", "image/x-rwz",
            "image/x-pentax-pef", "image/x-pentax-ptx", "image/x-sigma-x3f", "image/x-sony-srf", "image/x-sony-sr2",
            "image/x-samsung-srw", "image/x-sony-arw", "image/x-phaseone-iiq", "image/x-mamiya-mef", "image/x-leica-rwl",
            "image/x-hasselblad-3fr"
        ]

        let knownRawExtensions: Set<String> = [
            "dcraw", "dng", "crw", "cr2", "cr3", "erf", "fff", "raf", "dcr", "k25", "kdc", "mos", "mrw",
            "nef", "nrw", "orf", "raw", "rw2", "rwz", "pef", "ptx", "x3f", "srf", "sr2", "srw", "arw",
            "iiq", "mef", "rwl", "3fr"
        ]

        return MimeType(value: mimeType).isRaw || knownRawMimeTypes.contains(mime) || knownRawExtensions.contains(fileExtension)
    }
}
