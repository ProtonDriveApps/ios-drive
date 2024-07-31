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

extension CloudSlot {
    typealias ShareShortMeta = PDClient.ShareShort
    typealias ShareMeta = PDClient.Share
    typealias ShareObj = PDCore.Share
    typealias VolumeMeta = PDClient.Volume
    typealias VolumeObj = PDCore.Volume
    typealias RevisionMeta = PDClient.Revision
    typealias RevisionObj = PDCore.Revision
    
    typealias LinkMeta = PDClient.Link
    typealias NodeObj = PDCore.Node
    typealias FolderObj = PDCore.Folder
    typealias FileObj = PDCore.File
    typealias PhotoObj = PDCore.Photo
    typealias BlockObj = PDCore.Block
    
    typealias ShareURLMeta = PDClient.ShareURLMeta
    
    enum UpdateMode {
        case replace, append
    }
        
    /// Creates or updates Shares. Will create minimal objects for Volumes and Links as side effect, or will update relationships on present ones.
    @discardableResult
    func update(_ shares: [ShareShortMeta], in moc: NSManagedObjectContext) -> [ShareObj] {
        var result: [ShareObj] = []
        
        // switch to MOC's thread
        moc.performAndWait {
            // get all affected IDs
            var affectedIds = (
                shares: Set<ShareMeta.ShareID>(),
                files: Set<LinkMeta.LinkID>(),
                folders: Set<LinkMeta.LinkID>(),
                photos: Set<LinkMeta.LinkID>(),
                volumes: Set<VolumeMeta.VolumeID>()
            )
            
            shares.forEach {
                affectedIds.shares.insert($0.shareID)
                affectedIds.volumes.insert($0.volumeID)
                affectedIds.files.insert($0.linkID)
                affectedIds.photos.insert($0.linkID)
                affectedIds.folders.insert($0.linkID)
            }
            
            // create minimal objects for them
            let uniqueShares: [ShareObj] = self.storage.unique(with: affectedIds.shares, in: moc)
            let uniqueFiles: [FileObj] = self.storage.existing(with: affectedIds.files, in: moc)
            let uniquePhotos: [PhotoObj] = self.storage.existing(with: affectedIds.photos, allowSubclasses: true, in: moc)
            let uniqueFolders: [FolderObj] = self.storage.existing(with: affectedIds.folders, in: moc)
            let uniqueVolumes: [VolumeObj] = self.storage.unique(with: affectedIds.volumes, in: moc)
            
            // set up share and relationships
            result = shares.compactMap { shareMeta in
                // root may be either folder or file or photo
                let node = uniqueFolders.first { $0.id == shareMeta.linkID } ?? uniqueFiles.first { $0.id == shareMeta.linkID } ?? uniquePhotos.first { $0.id == shareMeta.linkID }
                let volume = uniqueVolumes.first { $0.id == shareMeta.volumeID }
                let share = uniqueShares.first { $0.id == shareMeta.shareID }
                
                share?.setValue(node, forKey: #keyPath(ShareObj.root))
                share?.setValue(volume, forKey: #keyPath(ShareObj.volume))
                share?.fulfill(from: shareMeta)
                
                node?.directShares.insert(share!)
                if shareMeta.flags.contains(.main) {
                    node?.setValue(shareMeta.shareID, forKey: #keyPath(NodeObj.shareID))
                }
                
                return share
            }
        }
        
        return result
    }
    
    @discardableResult
    func update(_ volumes: [VolumeMeta], in moc: NSManagedObjectContext) -> [VolumeObj] {
        var result: [VolumeObj] = []
        
        // switch to MOC's thread
        moc.performAndWait {
            // get all affected IDs
            let affectedIds = Set<VolumeMeta.VolumeID>(volumes.map(\.volumeID))
            
            // create minimal objects for them
            let uniqueVolumes: [VolumeObj] = self.storage.unique(with: affectedIds, in: moc)
            
            // set up share and relationships
            result = volumes.compactMap { volumeMeta in
                let volume = uniqueVolumes.first { $0.id == volumeMeta.volumeID }
                volume?.fulfill(from: volumeMeta)
                return volume
            }
        }
        
        return result
    }
    
    @discardableResult
    func update(_ shares: [ShareMeta], in moc: NSManagedObjectContext) -> [ShareObj] {
        let result: [ShareObj] = self.update(shares.map(ShareShortMeta.init), in: moc)
        zip(result, shares).forEach { $0.fulfill(from: $1) }
        return result
    }
    
    @discardableResult
    func update(_ share: ShareMeta, in moc: NSManagedObjectContext) -> ShareObj {
        return update([share], in: moc).first!
    }
    
    @discardableResult
    func update(_ shareUrls: [ShareURLMeta], in moc: NSManagedObjectContext) -> [ShareURL] {
        shareUrls.map { self.update($0, in: moc) }
    }
    
    @discardableResult
    func update(_ shareURLMeta: ShareURLMeta, in moc: NSManagedObjectContext) -> ShareURL {
        let shareUrl: ShareURL = self.storage.unique(with: Set([shareURLMeta.shareURLID]), uniqueBy: "id", in: moc).first!
        shareUrl.fulfill(from: shareURLMeta)
        
        let shares: [ShareObj] = self.storage.unique(with: Set([shareURLMeta.shareID]), in: moc)
        let share = shares.first!
        shareUrl.setValue(share, forKey: #keyPath(ShareURL.share))
        share.shareUrls.insert(shareUrl)
        
        return shareUrl
    }
    
    @discardableResult
    func update(_ links: [LinkMeta], of shareID: ShareMeta.ShareID, in moc: NSManagedObjectContext) -> [NodeObj] {
        var result: [NodeObj] = []
        
        // switch to MOC's thread
        moc.performAndWait {
            // get all affected IDs
            var affectedIds = (
                files: Set<LinkMeta.LinkID>(),
                folders: Set<LinkMeta.LinkID>(),
                revisions: Set<RevisionMeta.RevisionID>(),
                shares: Set<ShareMeta.ShareID>(),
                photos: Set<String>(),
                photoRevisions: Set<String>()
            )
            links.forEach { link in
                if let parent = link.parentLinkID {
                    affectedIds.folders.insert(parent)
                }
                if let shareID = link.sharingDetails?.shareID { affectedIds.shares.insert(shareID) }
                switch link.type {
                case .file:
                    let photo = link.fileProperties?.activeRevision?.photo
                    let isPhoto = photo != nil
                    if isPhoto {
                        affectedIds.photos.insert(link.linkID)
                        affectedIds.photos.formUnion([photo?.mainPhotoLinkID].compactMap { $0 })
                    } else {
                        affectedIds.files.insert(link.linkID)
                    }
                    guard let revision = link.fileProperties?.activeRevision else { return }
                    if isPhoto {
                        affectedIds.photoRevisions.insert(revision.ID)
                    } else {
                        affectedIds.revisions.insert(revision.ID)
                    }

                case .folder:
                    affectedIds.folders.insert(link.linkID)
                @unknown default: assert(false, "Unknown node type")
                }
            }
            
            // create minimal objects for them
            let uniqueFiles: [FileObj] = self.storage.unique(with: Set(affectedIds.files), in: moc)
            let uniqueFolders: [FolderObj] = self.storage.unique(with: Set(affectedIds.folders), in: moc)
            let uniqueRevisions: [RevisionObj] = self.storage.unique(with: Set(affectedIds.revisions), in: moc)
            let uniqueShares: [ShareObj] = self.storage.unique(with: Set(affectedIds.shares), in: moc)
            let uniquePhotos: [Photo] = self.storage.unique(with: Set(affectedIds.photos), in: moc)
            let uniquePhotoRevisions: [PhotoRevision] = self.storage.unique(with: Set(affectedIds.photoRevisions), in: moc)
            
            // set up share and relationships
            result = links.compactMap { link in
                let nodeObj: NodeObj? = uniqueFiles.first { $0.id == link.linkID } ?? uniqueFolders.first { $0.id == link.linkID } ?? uniquePhotos.first { $0.id == link.linkID }
                let parentLinkObj = uniqueFolders.first { $0.id == link.parentLinkID }
                let directShares = uniqueShares.filter { link.sharingDetails?.shareID == $0.id }
                parentLinkObj?.setValue(shareID, forKey: #keyPath(NodeObj.shareID))

                if let photo = nodeObj as? Photo,
                   let revisionResponse = link.fileProperties?.activeRevision,
                   let localRevision = uniquePhotoRevisions.first(where: { $0.id == revisionResponse.ID })
                {
                    photo.addToRevisions(localRevision)
                    photo.photoRevision = localRevision
                    photo.activeRevision = localRevision
                    localRevision.fulfill(link: link, revision: revisionResponse)

                    if revisionResponse.hasThumbnail, let thumbnails = revisionResponse.thumbnails {
                        addThumbnails(thumbnails, revision: localRevision, in: moc)
                    }
                    if let mainPhotoId = link.fileProperties?.activeRevision?.photo?.mainPhotoLinkID,
                       let mainPhoto = uniquePhotos.first(where: { $0.id == mainPhotoId }) {
                           photo.parent = mainPhoto
                    }
                } else if let fileObj = nodeObj as? FileObj,
                    let revisionResponse = link.fileProperties?.activeRevision,
                    let localRevision = uniqueRevisions.first(where: { $0.id == revisionResponse.ID })
                {
                    fileObj.addToRevisions(localRevision)
                    fileObj.activeRevision = localRevision
                    localRevision.fulfill(from: revisionResponse)

                    if revisionResponse.hasThumbnail, let thumbnails = revisionResponse.thumbnails {
                        addThumbnails(thumbnails, revision: localRevision, in: moc)
                    }
                }
                nodeObj?.setValue(parentLinkObj, forKey: #keyPath(NodeObj.parentLink))
                nodeObj?.setValue(shareID, forKey: #keyPath(NodeObj.shareID))
                (nodeObj as? FileObj)?.fulfill(from: link)
                (nodeObj as? FolderObj)?.fulfill(from: link)
                (nodeObj as? Photo)?.fulfillPhoto(from: link)
                
                directShares.forEach { share in
                    share.setValue(nodeObj, forKey: #keyPath(ShareObj.root))
                    nodeObj?.directShares.insert(share)
                }
                
                return nodeObj
            }
        }
        
        return result
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
            return Thumbnail.make(id: id, downloadURL: nil, revision: revision, type: type, hash: hash, in: moc)
        }
    }

    private func updateThumbnails(with urls: [ThumbnailURL], in moc: NSManagedObjectContext) {
        let ids = Set(urls.map(\.id))
        let thumbnails: [Thumbnail] = self.storage.existing(with: ids, in: moc)
        for thumbnail in thumbnails {
            guard let info = urls.first(where: { $0.id == thumbnail.id }) else {
                continue
            }
            guard thumbnail.downloadURL != info.url.absoluteString else {
                continue
            }
            thumbnail.downloadURL = info.url.absoluteString
        }
    }
    
    @discardableResult
    func update(_ folder: LinkMeta, of shareID: ShareMeta.ShareID, in moc: NSManagedObjectContext) -> FolderObj {
        var result: Folder!
        
        // switch to MOC's thread
        moc.performAndWait {
            // set up share and relationships
            let folderObj: FolderObj = self.storage.unique(with: Set([folder.linkID]), in: moc).first!
            
            var parentLinkObj: FolderObj?
            if let parentLinkID = folder.parentLinkID {
                parentLinkObj = self.storage.unique(with: Set([parentLinkID]), in: moc).first!
                parentLinkObj?.setValue(shareID, forKey: #keyPath(NodeObj.shareID))
            }
            
            folderObj.setValue(parentLinkObj, forKey: #keyPath(NodeObj.parentLink))
            folderObj.setValue(shareID, forKey: #keyPath(NodeObj.shareID))
            folderObj.fulfill(from: folder)
            
            result = folderObj
        }
        
        return result
    }
    
    @discardableResult
    func update(_ children: [LinkMeta],
                under folderID: LinkMeta.LinkID,
                of shareID: ShareMeta.ShareID,
                mode: UpdateMode = .replace,
                in moc: NSManagedObjectContext) -> [NodeObj]
    {
        let children = self.update(children, of: shareID, in: moc)
        var result: [NodeObj] = []
        
        // switch to MOC's thread
        moc.performAndWait {
            let folderObj: FolderObj = self.storage.unique(with: Set([folderID]), in: moc).first!
            switch mode {
            case .replace:
                folderObj.children = Set(children)
            case .append:
                folderObj.children.formUnion(Set(children))
            }
            
            result = children
        }
        
        return result
    }
        
    @discardableResult
    func update(_ revision: RevisionMeta,
                inFileID fileID: LinkMeta.LinkID,
                of shareID: ShareMeta.ShareID,
                in moc: NSManagedObjectContext) -> RevisionObj
    {
        var result: RevisionObj!
        
        // switch to MOC's thread
        moc.performAndWait {
            // set up share and relationships
            let revisionObj: RevisionObj = self.storage.unique(with: Set([revision.ID]), allowSubclasses: true, in: moc).first!
            revisionObj.fulfill(from: revision)

            let fileObj: File = self.storage.unique(with: Set([fileID]), allowSubclasses: true, in: moc).first!
            fileObj.setValue(shareID, forKey: #keyPath(NodeObj.shareID))
            
            self.storage.removeOldBlocks(of: revisionObj)
            
            let newBlocks: [DownloadBlock] = self.storage.unique(with: Set(revision.blocks.map { $0.URL.absoluteString }),
                                                         uniqueBy: #keyPath(DownloadBlock.downloadUrl),
                                                         in: moc)
            newBlocks.forEach { block in
                let meta = revision.blocks.first { $0.URL.absoluteString == block.downloadUrl }!
                block.fulfill(from: meta)
                block.setValue(revisionObj, forKey: #keyPath(BlockObj.revision)) 
            }
            
            revisionObj.setValue(fileObj, forKey: #keyPath(RevisionObj.file))
            revisionObj.blocks = Set(newBlocks)
            result = revisionObj
        }
        
        return result
    }
    
    @discardableResult
    func update(_ revisionID: RevisionMeta.RevisionID,
                inFileID fileID: LinkMeta.LinkID,
                of shareID: ShareMeta.ShareID,
                in moc: NSManagedObjectContext) -> RevisionObj
    {
        var result: RevisionObj!

        moc.performAndWait {
            // set up new revision and relationships
            let revisionObj: RevisionObj = self.storage.unique(with: Set([revisionID]), in: moc).first!

            let fileObj: File = self.storage.unique(with: Set([fileID]), in: moc).first!
            fileObj.setValue(shareID, forKey: #keyPath(NodeObj.shareID))

            revisionObj.setValue(fileObj, forKey: #keyPath(RevisionObj.file))
            fileObj.addToRevisions(revisionObj)
            result = revisionObj
        }

        return result
    }
    
    @discardableResult
    func update(_ newFileDetails: NewFile, file: FileObj) -> FileObj {
        let moc = file.managedObjectContext!
        moc.performAndWait {
            file.fulfill(from: newFileDetails)
            
            let revision: RevisionObj = self.storage.unique(with: Set([newFileDetails.revisionID]), in: moc).first!
            file.activeRevision = revision
            file.addToRevisions(revision)
        }
        return file
    }
    
    @discardableResult
    func update(_ newFolderDetails: NewFolder, folder: FolderObj) -> FolderObj {
        let moc = folder.managedObjectContext!
        moc.performAndWait {
            folder.fulfill(from: newFolderDetails)
        }
        return folder
    }
}

extension CloudSlot {
    typealias Outcome = (Result<Void, Error>) -> Void
    
    func trash(shareID: Client.ShareID, parentLinkID: Client.LinkID, linkIDs: [Client.LinkID], breadcrumbs: Breadcrumbs, completion: @escaping Outcome)  {
        client.trashNodes(shareID: shareID, parentLinkID: parentLinkID, linkIDs: linkIDs, breadcrumbs: breadcrumbs.collect(), completion: completion)
    }

    func delete(shareID: Client.ShareID, linkIDs: [Client.LinkID], completion: @escaping Outcome) {
        client.deletePermanently(shareID: shareID, linkIDs: linkIDs, completion: completion)
    }

    func emptyTrash(shareID: Client.ShareID, completion: @escaping Outcome) {
        client.emptyTrash(shareID: shareID, completion: completion)
    }

    func restore(shareID: Client.ShareID, linkIDs: [Client.LinkID], completion: @escaping (Result<[PartialFailure], Error>) -> Void)  {
        client.retoreTrashNode(shareID: shareID, linkIDs: linkIDs, completion: completion)
    }
    
}

extension CloudSlot {
    func trash(shareID: Client.ShareID, parentID: Client.LinkID, linkIDs: [Client.LinkID]) async throws {
        try await client.trash(shareID: shareID, parentID: parentID, linkIDs: linkIDs)
    }

    func delete(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws {
        try await client.deletePermanently(shareID: shareID, linkIDs: linkIDs)
    }
    
    func emptyTrash(shareID: Client.ShareID) async throws {
        try await client.emptyTrash(shareID: shareID)
    }
    
    func restore(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws -> [PartialFailure] {
        try await client.retoreTrashNode(shareID: shareID, linkIDs: linkIDs)
    }
    
}

extension CloudSlot {
    public func update(links: [PDClient.Link], shareId: String, managedObjectContext: NSManagedObjectContext) throws {
        try managedObjectContext.performAndWait {
            update(links, of: shareId, in: managedObjectContext)
            try managedObjectContext.saveOrRollback()
        }
    }
}

extension CloudSlot: ThumbnailsUpdateRepository {
    public func update(thumbnails: [ThumbnailURL]) throws {
        try moc.performAndWait {
            updateThumbnails(with: thumbnails, in: moc)
            try moc.saveOrRollback()
        }
    }
}
