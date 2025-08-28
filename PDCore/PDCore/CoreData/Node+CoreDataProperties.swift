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
    @NSManaged public var volumeID: String
    @NSManaged public var signatureEmail: String?
    @NSManaged public var nameSignatureEmail: String?
    @NSManaged public var size: Int
    @NSManaged public var directShares: Set<Share>
    @available(*, deprecated, message: "Don't use directly, use `parentNode: Node?` or `parentFolder: Folder?`")
    @NSManaged public var parentLink: Folder?
    @NSManaged public var isToBeDeleted: Bool
    @NSManaged public var isShared: Bool
    @NSManaged public var isSharedWithMeRoot: Bool

    public var parentFolder: Folder? {
        get { parentLink }
        set { parentLink = newValue }
    }

    public func getContextShare() throws -> Share {
        // Traverse up to the root node
        let rootNode = findRootNode()

        // Return the first direct share found on the root node, if any
        if let rootShare = rootNode.directShares.first {
            return rootShare
        }

        // If no share is found, throw an error indicating the invalid state
        throw invalidState("Root node has no associated context share.")
    }

    public func getContextShareAddressID() throws -> String {
        let share = try getContextShare()
        let addressID = try share.getAddressID()
        return addressID
    }

    public func setShareID(_ shareID: String) {
        self.shareID = shareID
    }

    public func isNodeShared() -> Bool {
        guard let share = directShares.first, share.type == .standard else {
            return false
        }
        return true
    }

    // Heavy operation, should only be used in case of error handling
    public func isSignatureVerifiable() -> Bool {
        // The root node of a main volume cannot be shared (will be `main` type).
        // On the other hand, root share of a shared file must be `standard` type.
        !findRootNode().isNodeShared()
    }

    public var shareId: String {
        // Case of macOS and iOS my files + photos + devices (future)
        if !self.shareID.isEmpty {
            return shareID
        }
        // Case of files that are SharedWithMe
        else {
            do {
                return try getContextShare().id
            } catch {
                Log.error(error: NukingCacheError(error), domain: .storage)
                #if os(iOS)
                NotificationCenter.default.nukeCache(reason: error.localizedDescription)
                #endif
                return ""
            }
        }
    }

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
    @NSManaged public var clearName: String?
    
    @objc public var isFolder: Bool {
        // This transient property is useful for fetch requests where we can not check the exact type of the node so we have no other choice. On the higher levels (apps) we'd better rely on the type of the object (is Folder, is File) because mimeType may have improper contents
        self.mimeType == Folder.mimeType
    }
    
    // Theoretically, only root node can have share with .main flag, and it should not be possible to create custom direct share for the root node. Let's prioritize such share thought for the sake of safety.
    public var primaryDirectShare: Share? {
        directShares.first(where: { $0.type == .main }) ?? directShares.first
    }

    public var isAnonymous: Bool {
        signatureEmail?.isEmpty ?? true
    }
}

public extension Node {
    var acceptsThumbnail: Bool {
        guard let file = self as? File else { return false }
        return file.supportsThumbnail
    }

    var isDownloadable: Bool {
        guard let file = self as? File else { return true }
        return !file.isProtonFile
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

extension Node {
    @objc(addDirectSharesObject:)
    @NSManaged public func addToDirectShares(_ value: Share)

    @objc(removeDirectSharesObject:)
    @NSManaged public func removeFromDirectShares(_ value: Share)

    @objc(addDirectShares:)
    @NSManaged public func addToDirectShares(_ values: Set<Share>)

    @objc(removeDirectShares:)
    @NSManaged public func removeFromDirectShares(_ values: Set<Share>)
}

public enum Role: Int16, Comparable {
    case viewer = 4
    case editor = 6
    case admin = 22

    public static func < (lhs: Role, rhs: Role) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension Node {
    public func getNodeRole() -> Role {
        if let parentNode {
            let parentRole = parentNode.getNodeRole()
            let currentRole: Role
            if let permissions = directShares.first?.members.first?.permissions,
               let role = Role(rawValue: permissions) {
                currentRole = role
            } else {
                currentRole = parentRole
            }
            return max(parentRole, currentRole)
        } else {
            if let permissions = directShares.first?.members.first?.permissions,
               let role = Role(rawValue: permissions) {
                return role
            }
            return .admin
        }
    }
    
    /// Has this item been shared with anyone?
    public var hasDirectShare: Bool {
        directShares.first == nil ? false : true
    }
}
