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
import PDClient

public typealias CoreDataShare = Share

@objc(Share)
public class Share: NSManagedObject, GloballyUnique {

    @NSManaged public var id: String
    @NSManaged public var volumeID: String
    @NSManaged public var type: ShareType
    @NSManaged public var state: ShareState
    @NSManaged public var creator: String?
    @NSManaged public var locked: Bool
    @NSManaged public var createTime: Date?
    @NSManaged public var modifyTime: Date?
    @NSManaged public var linkID: String?

    @NSManaged public var key: String?
    @NSManaged public var passphrase: String?
    @NSManaged public var passphraseSignature: String?
    @NSManaged public var addressID: String?
    @NSManaged public var addressKeyID: String?
    @NSManaged public var rootLinkRecoveryPassphrase: String?

    // Relationships
    @NSManaged public var root: Node?
    @NSManaged public var volume: Volume?
    @NSManaged public var device: Device?
    @NSManaged public var shareUrls: Set<ShareURL>
    @NSManaged public var members: Set<Membership>

    // transient
    @NSManaged internal var clearPassphrase: String?

    public var isMain: Bool {
        type == .main
    }

    public var isCollaborativelyShared: Bool {
        type == .standard
    }

    func getAddressID() throws -> String {
        if let member = members.first {
            return member.addressID
        } else {
            guard let addressID = addressID else {
                throw invalidState("Share has no member or addressID in share.")
            }
            return addressID
        }
    }

    public func isSignatureVerifiable() -> Bool {
        // Only main volume shares should be verifiable
        volume?.shares.contains(where: { $0.isMain }) ?? false
    }

    @objc public enum ShareType: Int16 {
        case undefined = 0
        case main = 1
        case standard = 2
        case device = 3
        case photos = 4
    }

    @objc public enum ShareState: Int16 {
        case active = 1
        case restored = 3
    }

    // MARK: - Deprecated
    @NSManaged fileprivate var flagsRaw: Int
    @NSManaged fileprivate var permissionMaskRaw: Int
    #if os(iOS)
    var _observation: Any?
    #endif

    // public enums, wrapped
    @ManagedEnum(raw: #keyPath(flagsRaw)) public var flags: Flags?

    // dangerous injection, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._flags.configure(with: self)
    }

    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }
}

// MARK: - Accessors for Members
extension Share {
    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: Membership)

    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: Membership)

    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: Set<Membership>)

    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: Set<Membership>)
}

// MARK: - Accessors for Share URLs
extension Share {
    @objc(addShareUrlsObject:)
    @NSManaged public func addToShareUrls(_ value: ShareURL)

    @objc(removeShareUrlsObject:)
    @NSManaged public func removeFromShareUrls(_ value: ShareURL)

    @objc(addShareUrls:)
    @NSManaged public func addToShareUrls(_ values: Set<ShareURL>)

    @objc(removeShareUrls:)
    @NSManaged public func removeFromShareUrls(_ values: Set<ShareURL>)
}

// MARK: - Deprecated
extension Share {
    public typealias Flags = PDClient.Share.Flags

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Share> {
        return NSFetchRequest<Share>(entityName: "Share")
    }

    override public func willChangeValue(forKey key: String) {
        switch key {
        case #keyPath(passphrase): self.clearPassphrase = nil
        default: break
        }

        super.willChangeValue(forKey: key)
    }

    override public func awakeFromFetch() {
        super.awakeFromFetch()
        #if os(iOS)
        if type != .photos {
            self._observation = self.subscribeToContexts()
        }
        #endif
    }

    override public func willTurnIntoFault() {
        super.willTurnIntoFault()
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }
}

extension Optional where Wrapped == PDClient.Share.Flags {
    public func contains(_ member: Wrapped) -> Bool {
        self?.contains(member) ?? false
    }
}

#if os(iOS)
extension Share: HasTransientValues {}
#endif

public extension Share {
    func fullfillWithBootstrappedShare(_ share: ShareMetadata) {
        self.id = share.shareID
        self.volumeID = share.volumeID
        self.type  = ShareType(rawValue: Int16(share.type)) ?? .undefined
        self.state = ShareState(rawValue: Int16(share.state)) ?? .active
        self.creator = share.creator
        self.locked = share.locked ?? false
        self.createTime = share.createTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.modifyTime = share.modifyTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.linkID = share.linkID
        self.key = share.key
        self.passphrase = share.passphrase
        self.passphraseSignature = share.passphraseSignature
        self.addressID = share.addressID
        self.addressKeyID = share.addressKeyID
        self.rootLinkRecoveryPassphrase = share.rootLinkRecoveryPassphrase
    }
}

extension StorageManager {
    @discardableResult
    public func updateShare(_ shareMetadata: ShareMetadata, in moc: NSManagedObjectContext) -> Share {
        let volume = Volume.fetchOrCreate(id: shareMetadata.volumeID, in: moc)
        let share = Share.fetchOrCreate(id: shareMetadata.shareID, in: moc)
        let node = Node.fetch(id: shareMetadata.linkID, volumeID: shareMetadata.volumeID, allowSubclasses: true, in: moc)
        let memberships = updateMemberships(shareMetadata.memberships, in: moc)

        share.volume = volume
        share.root = node
        share.addToMembers(memberships)
        node?.addToDirectShares(share)

        share.fullfillWithBootstrappedShare(shareMetadata)
        return share
    }

    func updateMemberships(_ membershipsMetadata: [MembershipMetadata], in moc: NSManagedObjectContext) -> Set<Membership> {
        var memberships = Set<Membership>()
        for membershipMetadata in membershipsMetadata {
            let membership = Membership.fetchOrCreate(id: membershipMetadata.memberID, in: moc)
            membership.fullfill(membership: membershipMetadata)
            memberships.insert(membership)
        }
        return memberships
    }

    @discardableResult
    public func updateLinks(_ links: [PDClient.Link], in moc: NSManagedObjectContext) -> [Node] {
        var nodes: [Node] = []
        for link in links {
            nodes.append(updateLink(link, using: moc))

        }
        return nodes
    }

    @discardableResult
    public func updateLink(_ link: PDClient.Link, fetchingSharedWithMeRoot: Bool = false, using moc: NSManagedObjectContext) -> Node {
        let node: Node
        switch link.type {
        case .file:
            if link.fileProperties?.activeRevision?.photo != nil {
                let photo = Photo.fetchOrCreate(id: link.linkID, volumeID: link.volumeID, in: moc)

                if let activeRevision = link.fileProperties?.activeRevision {
                    let revision = PhotoRevision.fetchOrCreate(id: activeRevision.ID, volumeID: link.volumeID, in: moc)
                    photo.addToRevisions(revision)
                    photo.activeRevision = revision
                    photo.photoRevision = revision
                    revision.fulfillRevision(link: link, revision: activeRevision)
                    revision.photo = photo

                    if activeRevision.hasThumbnail, let thumbnails = activeRevision.thumbnails {
                        addThumbnails(thumbnails, revision: revision, in: moc)
                    }

                    if let mainPhotoID = link.fileProperties?.activeRevision?.photo?.mainPhotoLinkID,
                       let mainPhoto = Photo.fetch(id: mainPhotoID, volumeID: link.volumeID, in: moc) {
                           photo.parent = mainPhoto
                    }
                    if let relatedPhotosLinkIDs = link.fileProperties?.activeRevision?.photo?.relatedPhotosLinkIDs {
                        // Not needed unless primary & secondary are fetched in different batch. Added this to avoid such issues.
                        relatedPhotosLinkIDs.forEach { secondaryId in
                            if let secondaryPhoto = Photo.fetch(id: secondaryId, volumeID: link.volumeID, in: moc) {
                                photo.addToChildren(secondaryPhoto)
                            }
                        }
                    }
                }
                photo.fulfillPhoto(with: link)

                let factory = CoreDataPhotoFactory(managedObjectContext: moc, storageManager: self)
                factory.updatePhoto(photo: photo, link: link)

                node = photo
            } else {

                let file = File.fetchOrCreate(id: link.linkID, volumeID: link.volumeID, in: moc) as File
                if let activeRevision = link.fileProperties?.activeRevision {
                    let revision = Revision.fetchOrCreate(id: activeRevision.ID, volumeID: link.volumeID, in: moc)
                    file.addToRevisions(revision)
                    file.activeRevision = revision
                    revision.fulfillRevision(with: activeRevision)

                    if activeRevision.hasThumbnail, let thumbnails = activeRevision.thumbnails {
                        addThumbnails(thumbnails, revision: revision, in: moc)
                    }
                }

                file.fulfillFile(with: link)
                node = file
            }

        case .folder:
            let folder = Folder.fetchOrCreate(id: link.linkID, volumeID: link.volumeID, in: moc) as Folder
            folder.fulfillFolder(with: link)
            node = folder

        case .album:
            let resource = CoreDataAlbumFactory(managedObjectContext: moc)
            let album = resource.updateOrCreateAlbum(link: link)
            node = album
        }

        if let sharingDetails = link.sharingDetails {
            let share = Share.fetchOrCreate(id: sharingDetails.shareID, in: moc)
            share.volumeID = link.volumeID
            share.type = getShareType(share)
            node.addToDirectShares(share)

            let types: [Share.ShareType] = [.main, .photos, .device]
            if types.contains(share.type) {
                node.setShareID(share.id)
            }

            if let shareURLMeta = sharingDetails.shareUrl {
                updateShareURL(shareURLMeta, in: moc)
                node.isShared = true
            } else {
                share.shareUrls.forEach(moc.delete)
                node.isShared = false
            }
        } else {
            node.directShares.forEach(moc.delete)
            node.isShared = false
        }

        if let parentLinkID = link.parentLinkID {
            if let photo = node as? Photo {
                updatePhotoParent(link: link, photo: photo, parentLinkID: parentLinkID, isRootNodeOptional: fetchingSharedWithMeRoot, moc: moc)
            } else {
                updateParent(link: link, node: node, parentLinkID: parentLinkID, isRootNodeOptional: fetchingSharedWithMeRoot, moc: moc)
            }
        } else {
            node.setShareID(node.directShares.first?.id ?? "")
        }

        return node
    }

    private func updateParent(link: Link, node: Node, parentLinkID: String, isRootNodeOptional: Bool, moc: NSManagedObjectContext) {
        if isRootNodeOptional {
            let parent = Folder.fetch(id: parentLinkID, volumeID: link.volumeID, in: moc)
            parent?.addToChildren(node)
            node.setShareID("")
        } else {
            let parent: Folder
            switch Folder.fetchOrCreateIndicatingResult(id: parentLinkID, volumeID: link.volumeID, in: moc) {
            case .fetched(let folder):
                parent = folder
            case .created(let folder):
                assertionFailure("Parent should already exist but was not found in the database")
                Log.warning("Parent was created when updating the child node but should already exist", domain: .metadata, sendToSentryIfPossible: true)
                parent = folder
            }
            // or an album needs to be created
            parent.addToChildren(node)
            node.setShareID(parent.shareId)
        }
    }

    private func updatePhotoParent(link: Link, photo: Photo, parentLinkID: String, isRootNodeOptional: Bool, moc: NSManagedObjectContext) {
        if isRootNodeOptional {
            // For root photos we may not have any parent - it's allowed state.
            // They can have a shared parent though, in such case we try to find it to complete the nodes graph
            if let parentFolder = Folder.fetch(id: parentLinkID, volumeID: link.volumeID, in: moc) {
                photo.parentFolder = parentFolder
            } else if let album = CoreDataAlbum.fetch(id: parentLinkID, volumeID: link.volumeID, in: moc) {
                photo.addToAlbums(album)
            }
            photo.setShareID("")
        } else {
            // For non-root photos we need to have a parent in DB prior to storing it.
            if let parentFolder = Folder.fetch(id: parentLinkID, volumeID: link.volumeID, in: moc) {
                photo.parentFolder = parentFolder
                photo.setShareID(parentFolder.shareId)
            } else if let album = CoreDataAlbum.fetch(id: parentLinkID, volumeID: link.volumeID, in: moc) {
                photo.addToAlbums(album)
                photo.setShareID(album.shareId)
            } else {
                Log.error(
                    "Storing metadata for a photo that requires a parentLink, but it's not in the DB",
                    error: nil,
                    domain: .storage
                )
            }
        }
    }

    private func addThumbnails(_ thumbnails: [PDClient.Thumbnail], revision: Revision, in moc: NSManagedObjectContext) {
        thumbnails.forEach { thumbnail in
            let thumbnailID = thumbnail.thumbnailID
            let thumbnailType: ThumbnailType = thumbnail.type == 1 ? .default : .photos

            let localThumbnail = getLocalThumbnail(id: thumbnailID, type: thumbnailType, hash: thumbnail.hash, revision: revision, moc: moc)
            localThumbnail.id = thumbnailID
            localThumbnail.type = thumbnailType
            localThumbnail.sha256 = Data(base64Encoded: thumbnail.hash)
        }
    }

    private func getLocalThumbnail(id: String, type: ThumbnailType, hash: String, revision: Revision, moc: NSManagedObjectContext) -> Thumbnail {
        let localThumbnailByID = revision.thumbnails.first(where: { $0.id == id })
        let localThumbnailByType = revision.thumbnails.first(where: { $0.type == type })

        if let localThumbnail = localThumbnailByID ?? localThumbnailByType {
            return localThumbnail
        } else {
            let thumbnail = Thumbnail.make(id: id, downloadURL: nil, revision: revision, type: type, hash: hash, in: moc)
            thumbnail.volumeID = revision.volumeID
            return thumbnail
        }
    }
}

extension Share {

    public var identifier: ShareIdentifier {
        ShareIdentifier(id: id)
    }

}
