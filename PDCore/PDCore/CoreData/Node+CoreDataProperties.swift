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
import CoreData

extension Node {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Node> {
        return NSFetchRequest<Node>(entityName: "Node")
    }
 
    @NSManaged public var name: String? // encrypted value, makes no sense in the higher level, use .decryptedName instead
    @NSManaged public var attributesMaskRaw: Int
    @NSManaged public var dirtyIndex: Int64
    @NSManaged public var id: String
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isInheritingOfflineAvailable: Bool
    @NSManaged public var isMarkedOfflineAvailable: Bool
    @NSManaged public var localID: String?
    @NSManaged public var mimeType: String
    @NSManaged public var nodeHash: String
    @NSManaged public var nodeKey: String
    @NSManaged public var nodePassphrase: String
    @NSManaged public var nodePassphraseSignature: String
    @NSManaged public var permissionsMaskRaw: Int
    @NSManaged public var shareID: String
    @NSManaged public var signatureEmail: String?
    @NSManaged public var nameSignatureEmail: String?
    @NSManaged public var size: Int
    @NSManaged public var directShares: Set<Share>
    @NSManaged public var parentLink: Folder?
    @NSManaged public var isToBeDeleted: Bool
    @NSManaged public var isShared: Bool
    
    @NSManaged private var created: Date
    #warning("Provides safety but should be replaced by a non-Core Data clone of Node")
    // this adds safety to accessing complex data types such as Date when underlying Core Data object doesn't exist
    public var createdDate: Date {
        get {
            guard !isFault, !isDeleted else { return Date() }
            return created
        } set {
            created = newValue
        }
    }
    @objc public static let createdDateKeyPath = "created"
    
    @NSManaged private var modified: Date
    #warning("Provides safety but should be replaced by a non-Core Data clone of Node")
    // this adds safety to accessing complex data types such as Date when underlying Core Data object doesn't exist
    public var modifiedDate: Date {
        get {
            guard !isFault, !isDeleted else { return Date() }
            return modified
        } set {
            modified = newValue
        }
    }
    @objc public static let modifiedDateKeyPath = "modified"
    
    // transient
    @NSManaged internal var clearPassphrase: String?
    @NSManaged internal var clearName: String?
    
    @objc internal var isFolder: Bool {
        // This transient property is useful for fetch requests where we can not check the exact type of the node so we have no other choice. On the higher levels (apps) we'd better rely on the type of the object (is Folder, is File) because mimeType may have improper contents
        self.mimeType == Folder.mimeType
    }
    
    // Theoretically, only root node can have share with .main flag, and it should not be possible to create custom direct share for the root node. Let's prioritize such share thought for the sake of safety.
    public var primaryDirectShare: Share? {
        directShares.first(where: \.isMain) ?? directShares.first
    }
}

public extension Node {
    var acceptsThumbnail: Bool {
        guard let file = self as? File else { return false }
        return file.supportsThumbnail
    }

    var isDownloadable: Bool {
        guard let file = self as? File else { return true }
        return !file.isProtonDocument
    }

    func setIsInheritingOfflineAvailable(_ value: Bool) {
        // Only inherit `true` if is actually downloadable
        isInheritingOfflineAvailable = value && isDownloadable
    }
}

public extension Node {
    var isDirty: Bool {
        dirtyIndex != 0
    }
}
