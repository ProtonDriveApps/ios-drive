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

@objc(Photo)
public class Photo: File {
    @NSManaged public var captureTime: Date

    @NSManaged public var parent: Photo?
    @NSManaged public var children: Set<Photo>

    @NSManaged public var photoRevision: PhotoRevision
    
    // MainKey encrypted properties
    @NSManaged public var tempBase64Metadata: String?
    @NSManaged public var tempBase64Exif: String?

    // Deprecated
    @available(*, deprecated, message: "Not needed")
    @NSManaged override public var revisions: Set<Revision>

    @available(*, deprecated, message: "Not needed")
    @NSManaged override public var activeRevision: Revision?

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
}

// MARK: - PDCore DTO's for saving metadata and exif

public struct TemporalMetadata: Codable {
    public let location: ExtendedAttributes.Location?
    public let camera: ExtendedAttributes.Camera?
    public let media: ExtendedAttributes.Media
    public let iOSPhotos: ExtendedAttributes.iOSPhotos
    
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
}
