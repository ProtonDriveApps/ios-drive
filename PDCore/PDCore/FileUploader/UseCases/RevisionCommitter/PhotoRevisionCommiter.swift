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

import CoreData
import Foundation

final class NewPhotoRevisionCommitter: NewFileRevisionCommitter {
    private let finishResource: PhotoUploadFinishResource

    init(cloudRevisionCommitter: CloudRevisionCommitter, uploadedRevisionChecker: UploadedRevisionChecker, signersKitFactory: SignersKitFactoryProtocol, moc: NSManagedObjectContext, finishResource: PhotoUploadFinishResource) {
        self.finishResource = finishResource
        super.init(cloudRevisionCommitter: cloudRevisionCommitter, uploadedRevisionChecker: uploadedRevisionChecker, signersKitFactory: signersKitFactory, moc: moc)
    }

    override func getPhotoIfNeeded(revision: Revision) throws -> CommitableRevision.Photo? {
        guard let photoRevision = revision as? PhotoRevision else {
            throw revision.invalidState("Revision should be a PhotoRevision.")
        }
        let photo = photoRevision.photo
        let xAttr = try revision.decryptedExtendedAttributes()

        guard let contentDigest = xAttr.common?.digests?.sha1 else {
            throw NewFileRevisionCommiterError.noDigestFount
        }

        guard let parentFolder = revision.file.parentNode else {
            throw revision.invalidState("A revision must belong to a file that is within a parent Folder")
        }

        let parent = try parentFolder.encrypting()
        let hmac = try Encryptor.hmac(filename: contentDigest, parentHashKey: parent.hashKey)
        return CommitableRevision.Photo(
            mainPhotoLinkID: photo.parent?.id,
            captureTime: Int(photo.captureTime.timeIntervalSince1970),
            exif: photoRevision.exif,
            contentHash: hmac,
            tags: photo.tags ?? []
        )
    }

    /// Template method that notifies parent for photos
    override func notifyParentIfNeeded(file: File) {
        guard let photo = file as? Photo,
        let parent = photo.parent else { return }

        let parentState = parent.state
        parent.state = parentState
    }
    
    override func finalizeRevision(in file: File, commitableRevision: CommitableRevision, completion: @escaping Completion) {
        moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }
            
            guard let revision = file.activeRevisionDraft else {
                return completion(.failure(file.invalidState("File should have an active revision draft.")))
            }

            revision.created = Date()
            revision.manifestSignature = commitableRevision.manifestSignature
            revision.state = .active

            file.activeRevision = revision
            file.addToRevisions(revision)
            file.size = revision.size
            file.state = .active

            guard let photo = file as? Photo else {
                return completion(.failure(file.invalidState("The file should be of type Photo.")))
            }
            
            if photo.children.isEmpty {
                file.uploadID = nil
                file.activeRevisionDraft = nil
                file.clientUID = nil
                // Need to insert listing once the full photo is uploaded
                updateListingsIfNeeded(photo: photo)
                // Remove the uploadID of the parent, if this is the last children uploaded
                removeUploadFromParentIfNeeded(from: photo.parent)
            } else {
                // Do not remove the upload id of photos with children, that should be done by the last children uploaded
                // file.uploadID = nil
                file.activeRevisionDraft = nil
                file.clientUID = nil
            }

            notifyParentIfNeeded(file: file)

            do {
                file.activeRevision?.removeBigThumbnails(in: self.moc)
                file.activeRevision?.removeOldBlocks(in: self.moc)
                try moc.saveOrRollback()
                // Perform immediately after saving 🚨, to ensure that there are no changes to the object’s relationships.
                // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/FaultingandUniquing.html
                self.moc.refresh(revision, mergeChanges: false)
                finishResource.execute(with: photo)
                completion(.success)
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    private func removeUploadFromParentIfNeeded(from parent: Photo?) {
        guard let parent = parent else { return }
        if parent.children.allSatisfy({ $0.state == .active }) {
            parent.uploadID = nil
        }
    }

    private func updateListingsIfNeeded(photo: Photo) {
        let parentPhoto = photo.parent ?? photo
        let allPhotos = [parentPhoto] + parentPhoto.children
        if allPhotos.allSatisfy({ $0.state == .active }) {
            updatePhotoListing(photo: parentPhoto)
        }
    }

    private func updatePhotoListing(photo: CoreDataPhoto) {
        guard let managedObjectContext = photo.managedObjectContext else {
            return
        }

        let listing = makePhotoListing(photo: photo, managedObjectContext: managedObjectContext)
        let children = photo.children.map { makePhotoListing(photo: $0, managedObjectContext: managedObjectContext) }
        listing.addToRelatedPhotos(Set(children))
    }

    private func makePhotoListing(photo: CoreDataPhoto, managedObjectContext: NSManagedObjectContext) -> CoreDataPhotoListing {
        let identifier = PhotoListingIdentifier(id: photo.id, albumID: nil, volumeID: photo.volumeID)
        let listing = CoreDataPhotoListing.fetchOrCreate(identifier: identifier, in: managedObjectContext)
        listing.photo = photo
        listing.captureTime = photo.captureTime
        listing.nameHash = photo.nodeHash
        // Correct parameters will be populated by events, but atm we only need correct identifier and captureTime.
        listing.addedTime = Date()
        listing.contentHash = photo.photoRevision.clearXAttributes?.common?.digests?.sha1 ?? ""
        listing.tagsRaw = CoreDataPhotoListing.tagsSerializer.serialize(tags: photo.tags ?? [])
        return listing
    }
}

enum NewFileRevisionCommiterError: Error {
    case noDigestFount
}
