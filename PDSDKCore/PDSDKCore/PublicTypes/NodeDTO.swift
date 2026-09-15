// Copyright (c) 2026 Proton AG
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
@preconcurrency import PDCore
import ProtonDriveSDK

// MARK: - NodeDTO

/// Public sum type representing a node rendered in finder-style lists.
///
/// Mirrors the shape of `SDKDriveNode` so the discrimination is encoded once.
/// SDK-backed metadata (id, name, dates, authors, mime type) lives on the
/// stored `SDKFileNode` / `SDKFolderNode`; only fields the SDK does not yet
/// cover are mirrored locally on `NodeLocalDTO` and on each case's payload.
///
/// As the SDK gains parity, fields can be removed from `NodeLocalDTO` and
/// eventually the DTOs themselves can be retired in favour of `SDKDriveNode`
/// at call sites.
public enum NodeDTO: Identifiable, Sendable {
    case file(FileDTO)
    case folder(FolderDTO)

    var sdkDriveNode: SDKDriveNode {
        switch self {
        case .file(let file): return .file(file.sdkFileNode)
        case .folder(let folder): return .folder(folder.sdkFolderNode)
        }
    }

    public var local: NodeLocalDTO {
        switch self {
        case .file(let file): return file.local
        case .folder(let folder): return folder.local
        }
    }

    /// Builds the appropriate concrete DTO from a Core Data node.
    ///
    /// Must be called from within the node's managed object context.
    public init(node: CoreDataNode, signatureKeys: [PublicKey]) throws {
        switch node {
        case let folder as CoreDataFolder:
            self = .folder(try FolderDTO(folder: folder, signatureKeys: signatureKeys))
        case let file as CoreDataFile:
            self = .file(try FileDTO(file: file, signatureKeys: signatureKeys))
        default:
            throw CoreDataNode.InvalidState(message: "Given node is neither File nor Folder")
        }
    }
}

// MARK: - Flat convenience accessors

/// Making it obvious which fields will disappear once the SDK is feature-complete.
public extension NodeDTO {

    // MARK: SDK-backed

    var id: AnyVolumeIdentifier { sdkDriveNode.uid.any }
    var parentID: AnyVolumeIdentifier? { sdkDriveNode.parentUid?.any }
    var name: String { sdkDriveNode.name }
    var createdDate: Date { Date(timeIntervalSince1970: sdkDriveNode.creationTime) }
    var nameAuthor: SDKAuthor? { sdkDriveNode.nameAuthor }
    var keyAuthor: SDKAuthor? { sdkDriveNode.keyAuthor }
    var ownedBy: String? { sdkDriveNode.ownedBy.email ?? sdkDriveNode.ownedBy.organization }
    var activeRevision: SDKFileRevision? { sdkDriveNode.activeRevision }
    var mimeType: String {
        switch self {
        case .file(let file): return file.sdkFileNode.mediaType
        case .folder: return Folder.mimeType
        }
    }

    // MARK: Local-backed

    var objectID: NSManagedObjectID { local.objectID }
    var directShareObjectID: NSManagedObjectID? { local.directShareObjectID }
    var nodeIdentifier: NodeIdentifier { local.nodeIdentifier }
    var modificationDate: Date { local.modificationDate }
    var permissions: Permissions { local.permissions }
    var role: Role { local.role }
    var state: Node.State? { local.state }
    var membership: MembershipDTO? { local.membership }
    var isAvailableOffline: Bool { local.isAvailableOffline }
    var isDownloadable: Bool { local.isDownloadable }
    var isDownloaded: Bool { local.isDownloaded }
    var isEligibleForAvailableOffline: Bool { local.isEligibleForAvailableOffline }
    var isMarkedOfflineAvailable: Bool { local.isMarkedOfflineAvailable }
    var isFavorite: Bool { local.isFavorite }
    var isShared: Bool { local.isShared }
    var isSharedWithMeRoot: Bool { local.isSharedWithMeRoot }
}

// Temporary workaround for current iOS FFinderView.
// Decrypting extended attributes for all files is slow and harms UX,
// so we decrypt them on demand instead.
// We can revert to using SDKFileRevision once we implement node enumeration and read data from SDK
public extension NodeDTO {
    func extendedAttributes(performIn context: NSManagedObjectContext) -> ExtendedAttributes {
        guard isFile else { return ExtendedAttributes() }
        do {
            let node: CoreDataFile = try context.typedObject(with: objectID)
            guard let revision = node.activeRevision else { return ExtendedAttributes() }
            return try revision.decryptedExtendedAttributes()
        } catch {
            Log.error("Decrypt extended attributes failed", error: error, domain: .application)
            return ExtendedAttributes()
        }
    }
}

// MARK: - NodeLocalDTO

/// Local-only metadata not yet covered by the SDK. As the SDK gains parity,
/// remove fields here and switch their callers to read from the SDK node.
public struct NodeLocalDTO: Sendable {
    public let directShareObjectID: NSManagedObjectID?
    public let isAvailableOffline: Bool
    public let isDownloadable: Bool
    public let isDownloaded: Bool
    public let isEligibleForAvailableOffline: Bool
    public let isFavorite: Bool
    public let isMarkedOfflineAvailable: Bool
    public let isShared: Bool
    public let isSharedWithMeRoot: Bool
    public let editorsCanShare: Bool
    public let membership: MembershipDTO?
    public let modificationDate: Date
    public let nodeIdentifier: NodeIdentifier
    public let objectID: NSManagedObjectID
    public let permissions: Permissions
    public let role: Role
    public let state: Node.State?

    /// Must be initialized from within the node's managed object context.
    init(node: CoreDataNode) {
        self.objectID = node.objectID
        self.directShareObjectID = node.directShares.first?.objectID
        self.nodeIdentifier = node.identifier
        self.modificationDate = node.modifiedDate
        self.permissions = node.getNodePermissions()
        self.role = node.getNodeRole()
        self.state = node.state
        self.isAvailableOffline = node.isAvailableOffline
        self.isDownloadable = node.isDownloadable
        self.isDownloaded = node.isDownloaded
        self.isEligibleForAvailableOffline = node.isEligibleForAvailableOffline
        self.isMarkedOfflineAvailable = node.isMarkedOfflineAvailable
        self.isFavorite = node.isFavorite
        self.isShared = node.isShared
        self.isSharedWithMeRoot = node.isSharedWithMeRoot
        self.editorsCanShare = node.getStandardShare()?.editorsCanShare ?? false

        if let member = node.directShares.first?.members.first {
            self.membership = MembershipDTO(
                inviteTime: member.createTime,
                memberID: member.id,
                sharedBy: SDKAuthor(emailAddress: member.inviter, signatureVerificationError: nil),
                shareID: member.shareID
            )
        } else {
            self.membership = nil
        }
    }
}
