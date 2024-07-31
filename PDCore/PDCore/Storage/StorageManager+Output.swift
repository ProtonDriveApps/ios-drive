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

public extension StorageManager {

    func entities<E: NSManagedObject>(in moc: NSManagedObjectContext) throws -> [E] {
        var result: [E] = []
        try moc.performAndWait {
            let request = NSFetchRequest<E>()
            request.entity = E.entity()
            result = try moc.fetch(request)
        }
        return result
    }

    // Results
    func photosDevice(moc: NSManagedObjectContext) -> Device? {
        let request = requestDevices()
        request.predicate = NSPredicate(format: "%K == %d", #keyPath(Device.type), Device.´Type´.photos.rawValue)

        return moc.performAndWait {
            return (try? moc.fetch(request))?.first
        }
    }
    
    // Results
    func volumes(moc: NSManagedObjectContext) -> [Volume] {
        var result: [Volume] = []
        moc.performAndWait {
            result = (try? moc.fetch(self.requestVolumes())) ?? []
        }
        return result
    }

    /// Main share created by specific user and participating in volume
    func mainShareOfVolume(by addressIDs: Set<String>, moc: NSManagedObjectContext) -> Share? {
        /*
        ACCORDING TO JULIEN:
        In theory, Yes it is possible that /volumes will give up more than one volume. Not for the scope of the Beta though.
        Again, for the scope of the Beta, you'll only see 1 share here that will be the main share for your own volume. But in theory, yes, other user's shares might be present in the list, and as far I can see for now, the VolumeID will be present in the response.
        "Main shares" are flagged in the "Flags" field. We flag them Like this : 1 << 0 . So the flag, for now, is just 1
        */
        var result: [Share] = []
        moc.performAndWait {
            let sharesInDB = try? moc.fetch(self.requestSharesOfVolume())
            let connectedToVolumesOfCreator = sharesInDB ?? []
            let mainShares = connectedToVolumesOfCreator
                .filter(\.isMain)
                .filter({ $0.addressID != nil })
                .filter({ addressIDs.contains($0.addressID!) })
            assert(mainShares.count <= 1)
            result = mainShares
        }
        return result.first
    }

    func fetchShares(moc: NSManagedObjectContext) throws -> [Share] {
        return try moc.fetch(self.requestShares())
    }
    
    func fetchSupportedShares(moc: NSManagedObjectContext) throws -> [Share] {
        let request = requestShares()
        request.predicate = NSPredicate(
            format: "%K == %d OR %K == %d",
            #keyPath(Share.type), Share.ShareType.main.rawValue,
            #keyPath(Share.type), Share.ShareType.photos.rawValue
        )
        return try moc.fetch(request)
    }

    func fetchChildren(of parentID: String,
                       share shareID: String,
                       sorting: SortPreference,
                       moc: NSManagedObjectContext) throws -> [Node]
    {
        return try moc.performAndWait {
            let fetchRequest = self.requestChildren(node: parentID, share: shareID, sorting: sorting, moc: moc)
            return try moc.fetch(fetchRequest)
        }
    }

    func fetchChildrenUploadedByClientsOtherThan(_ clientUID: String,
                                                 with hash: String,
                                                 of parentID: String,
                                                 share shareID: String,
                                                 moc: NSManagedObjectContext) throws -> [Node]
    {
        return try moc.performAndWait {
            let fetchRequest = self.requestChildren(node: parentID, share: shareID, hash: hash, sorting: .default, moc: moc)
            let results = try moc.fetch(fetchRequest)
            return results.filter { node in
                if let file = node as? File, let fileClientUID = file.clientUID {
                    return fileClientUID != clientUID
                } else {
                    return true
                }
            }
        }
    }

    func fetchEntireChildCount(of parentID: String,
                               share shareID: String,
                               moc: NSManagedObjectContext) throws -> Int
    {
        return try moc.performAndWait {
            let fetchRequest = self.requestChildren(node: parentID, share: shareID, includeTrashed: true, sorting: .default, moc: moc)
            return try moc.count(for: fetchRequest)
        }
    }
    
    func fetchNode(id: NodeIdentifier, moc: NSManagedObjectContext) -> Node? {
        var node: Node?
        moc.performAndWait {
            let fetchRequest = self.requestNode(node: id.nodeID, share: id.shareID, moc: moc)
            node = try? moc.fetch(fetchRequest).first
        }
        return node
    }
    
    func fetchNodesCount(of share: String, moc: NSManagedObjectContext) async throws -> Int {
        try await moc.perform {
            let fetchRequest = self.requestNodes(share: share, sorting: .nameAscending, moc: moc)
            return try moc.count(for: fetchRequest)
        }
    }
    
    func fetchDraft(localID: String, shareID: String, moc: NSManagedObjectContext) -> File? {
        var draft: File?
        moc.performAndWait {
            let fetchRequest = self.requestDraft(localID: localID, share: shareID, moc: moc)
            draft = try? moc.fetch(fetchRequest).first
        }
        return draft
    }

    func fetchNodes(ids: [String], moc: NSManagedObjectContext) -> Set<Node> {
        var nodes: [Node]?
        moc.performAndWait {
            let fetchRequest = self.requestNodesOf(ids: ids, moc: moc)
            nodes = try? moc.fetch(fetchRequest)
        }
        return Set(nodes ?? [])
    }
    
    func fetchNodes(of shareID: String, moc: NSManagedObjectContext) -> [Node] {
        var nodes: [Node]?
        moc.performAndWait {
            let fetchRequest = self.requestNodes(share: shareID, sorting: .default, moc: moc)
            nodes = try? moc.fetch(fetchRequest)
        }
        return nodes ?? []
    }
    
    func fetchDirtyNodes(of shareID: String, moc: NSManagedObjectContext) async throws -> [Node] {
        try await moc.perform {
            try moc.fetch(self.requestDirtyNodes(share: shareID, moc: moc))
        }
    }
    
    func fetchDirtyNodesCount(share shareID: String, moc: NSManagedObjectContext) async throws -> Int {
        try await moc.perform {
            try moc.count(for: self.requestDirtyNodes(share: shareID, moc: moc))
        }
    }

    func fetchFilesUploading(moc: NSManagedObjectContext) -> [File] {
        var files = [File]()
        moc.performAndWait {
            let fetchRequest = self.requestFilesUploading(moc: moc)
            files = (try? moc.fetch(fetchRequest)) ?? []
        }
        return files
    }
    
    func fetchFilesInterrupted(moc: NSManagedObjectContext) -> [File] {
        var files = [File]()
        moc.performAndWait {
            let fetchRequest = self.requestFilesInterrupted(moc: moc)
            files = (try? moc.fetch(fetchRequest)) ?? []
        }
        return files
    }

    func fetchUploadingCount(moc: NSManagedObjectContext) -> Int {
        var count = 0
        moc.performAndWait {
            let fetchRequest: NSFetchRequest<NSNumber> = self.requestUploading(moc: moc)
            fetchRequest.resultType = .countResultType
            count = (try? moc.fetch(fetchRequest).first?.intValue) ?? 0
        }
        
        return count
    }

    func fetchTrashCount(moc: NSManagedObjectContext) -> Int {
        var count = 0
        moc.performAndWait {
            let fetchRequest: NSFetchRequest<NSNumber> = self.requestTrashResult(moc: moc)
            fetchRequest.resultType = .countResultType
            count = (try? moc.fetch(fetchRequest).first?.intValue) ?? 0
        }

        return count
    }

    func fetchWaitingFiles(maxSize: Int) -> [ReuploadingFile] {
        var files = [ReuploadingFile]()
        backgroundContext.performAndWait {
            let fetchRequest = self.requestWaitingFiles(maxSize: maxSize, moc: backgroundContext)
            files = ((try? backgroundContext.fetch(fetchRequest)) ?? []).filter({ !($0 is Photo) }).map { ReuploadingFile(size: $0.size, file: $0) }
        }
        return files
    }

    func fetchWaitingPhotos(maxSize: Int) -> [ReuploadingPhoto] {
        var photos = [ReuploadingPhoto]()
        backgroundContext.performAndWait {
            let fetchRequest = self.requestWaitingPhotos(maxSize: maxSize, moc: backgroundContext)
            photos = ((try? backgroundContext.fetch(fetchRequest)) ?? []).map { ReuploadingPhoto(size: $0.size, photo: $0) }
        }
        return photos
    }

    func fetchPhotos(ids: [String], moc: NSManagedObjectContext) -> [Photo] {
        return moc.performAndWait {
            let fetchRequest = requestPhotos(ids: ids, moc: moc)
            return (try? moc.fetch(fetchRequest)) ?? []
        }
    }

    func fetchLastPrimaryPhoto(moc: NSManagedObjectContext) -> Photo? {
        let request = requestPrimaryPhotos()
        request.fetchLimit = 1

        return try? moc.fetch(request).first
    }

    func fetchOldestPrimaryUploadedPhotoId(moc: NSManagedObjectContext) -> NodeIdentifier? {
        return moc.performAndWait {
            let request = requestPrimaryUploadedPhotos(ascending: true)
            request.fetchLimit = 1
            return try? moc.fetch(request).first?.identifier
        }
    }

    func fetchPrimaryPhotos(moc: NSManagedObjectContext) -> [Photo] {
        return moc.performAndWait {
            let fetchRequest = requestPrimaryPhotos()
            return (try? moc.fetch(fetchRequest)) ?? []
        }
    }

    func fetchPrimaryUploadedPhotos(moc: NSManagedObjectContext) -> [Photo] {
        return moc.performAndWait {
            let fetchRequest = requestPrimaryUploadedPhotos()
            return (try? moc.fetch(fetchRequest)) ?? []
        }
    }

    func fetchPhoto(id: NodeIdentifier, moc: NSManagedObjectContext) throws -> Photo {
        let result = moc.performAndWait {
            let fetchRequest = requestPhoto(id)
            return try? moc.fetch(fetchRequest)
        }
        guard let photo = result?.first else {
            throw Photo.noMOC()
        }
        return photo
    }

    func fetchPrimaryUploadingPhotos(moc: NSManagedObjectContext) -> [Photo] {
        moc.performAndWait {
            let fetchRequest = requestPrimaryUploadingPhotos()
            return (try? moc.fetch(fetchRequest)) ?? []
        }
    }

    func fetchUploadingPhotos(size: Int, moc: NSManagedObjectContext) -> [Photo] {
        var fetchedPhotos: [Photo] = []
        moc.performAndWait {
            // Child photos that have their parents uploaded
            if let photos = try? moc.fetch(requestChildPhotosWithUploadedParent(size: size)), !photos.isEmpty {
                fetchedPhotos.append(contentsOf: photos)
            }
            guard fetchedPhotos.count < size else { return }

            // Non uploaded main photos
            let states: [Photo.State] = [.interrupted, .uploading, .cloudImpediment]
            for state in states {
                // Calculate the remaining number of photos to fetch
                let remainingSize = size - fetchedPhotos.count
                guard remainingSize > 0 else { break } // Stop if we have fetched the desired number of photos

                if let photos = try? moc.fetch(requestPrimaryPhotos(ofState: state, size: remainingSize)) {
                    fetchedPhotos.append(contentsOf: photos)
                }
            }
        }
        return fetchedPhotos
    }

    /// Checks if there is at least one `Photo` object in an uploading state in the local database.
    ///
    /// This method performs a synchronous fetch on the provided managed object context to determine if any `Photo` objects are currently in one of the specified uploading states: `.interrupted`, `.uploading`, or `.cloudImpediment`. 
    /// The search is efficient, as it stops as soon as it finds the first photo in any of these states, minimizing database query time.
    ///  At this point we don't care if the unfinished Photo is a parent or a child, the upload algorithms should pick up the incumbent Photo in it's correct form.
    ///
    /// - Parameters:
    ///   - moc: The `NSManagedObjectContext` on which the fetch request is performed. The `NSManagedObjectContext` that should be used is the `photos` specific one.
    ///
    /// - Returns: A Boolean value indicating whether at least one `Photo` object is in an uploading state. Returns `true` if such a photo exists, otherwise returns `false`.
    func hasUploadingPhotos(moc: NSManagedObjectContext) -> Bool {
        var hasUploadingPhoto = false
        let states: [Photo.State] = [.interrupted, .uploading, .cloudImpediment]

        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(Photo.stateRaw), states.map { $0.rawValue })
        fetchRequest.fetchLimit = 1

        moc.performAndWait {
            do {
                let photos = try moc.count(for: fetchRequest)
                if photos > 0 {
                    hasUploadingPhoto = true
                }
            } catch {
                Log.error("Failed to fetch uploading photos: \(error)", domain: .backgroundTask)
            }
        }
        return hasUploadingPhoto
    }

    private func requestPrimaryPhotos(ofState state: Photo.State, size: Int) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == nil AND %K == %d",
            #keyPath(Photo.parent),
            #keyPath(Photo.stateRaw), state.rawValue
        )
        fetchRequest.fetchLimit = size
        return fetchRequest
    }

    private func requestPrimaryPhotosWithNonUploadedChildren(size: Int) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == nil AND %K == %d AND (ANY %K.%K == %d OR ANY %K.%K == %d OR ANY %K.%K == %d)",
            #keyPath(Photo.parent),
            #keyPath(Photo.stateRaw), Photo.State.active.rawValue,
            #keyPath(Photo.children), #keyPath(Photo.stateRaw), Photo.State.uploading.rawValue,
            #keyPath(Photo.children), #keyPath(Photo.stateRaw), Photo.State.cloudImpediment.rawValue,
            #keyPath(Photo.children), #keyPath(Photo.stateRaw), Photo.State.interrupted.rawValue
        )
        fetchRequest.fetchLimit = size
        return fetchRequest
    }

    private func requestChildPhotosWithUploadedParent(size: Int) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(
            format: "%K != nil AND %K.%K == %d AND (%K == %d OR %K == %d OR %K == %d)",
            #keyPath(Photo.parent),
            #keyPath(Photo.parent), #keyPath(Photo.stateRaw), Photo.State.active.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.uploading.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.cloudImpediment.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.interrupted.rawValue
        )
        fetchRequest.fetchLimit = size
        return fetchRequest
    }

    func fetchThumbnail(id: String, moc: NSManagedObjectContext) -> Thumbnail? {
        return moc.performAndWait {
            let fetchRequest = requestThumbnail(id: id)
            return try? moc.fetch(fetchRequest).first
        }
    }

    // TODO: Maybe fetch all file with linkID and shareID, and then filter the revisions by revisionID
    func fetchRevision(id: RevisionIdentifier, moc: NSManagedObjectContext) -> Revision? {
        var revision: Revision?
        moc.performAndWait {
            let fetchRequest = NSFetchRequest<Revision>()
            fetchRequest.entity = Revision.entity()
            fetchRequest.sortDescriptors = [.init(key: #keyPath(Revision.id), ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Revision.id), id.revision)
            revision = try? moc.fetch(fetchRequest).first
        }
        return revision
    }

    func isPhotoPresent(linkId: String, moc: NSManagedObjectContext) -> Bool {
        return moc.performAndWait {
            let fetchRequest = requestPhotoExists(id: linkId)
            let count = try? moc.fetch(fetchRequest).count
            return (count ?? 0) > 0
        }
    }
    
    func clearDrafts(moc: NSManagedObjectContext,
                     deleteDraft: @escaping (File) -> Void,
                     deleteRevisionOnBE: @escaping (Revision) -> Void,
                     includingAlreadyUploadedFiles: Bool) throws -> Bool {
        
        try moc.performAndWait {
            let fetchRequest: NSFetchRequest<File> = self.requestUploading(moc: moc)
            var didClearSomething = false
            try moc.fetch(fetchRequest)
                .forEach { file in
                    guard let unuploadedRevision = file.activeRevisionDraft else { return }
                    let fileID = file.id
                    let revisionID = unuploadedRevision.id
                    if file.isDraft() {
                        deleteDraft(file)
                        moc.delete(unuploadedRevision)
                        try moc.saveWithParentLinkCheck()
                        didClearSomething = true
                        Log.info("Cleared draft \(fileID) with revision \(revisionID)", domain: .storage)
                    } else if includingAlreadyUploadedFiles {
                        deleteRevisionOnBE(unuploadedRevision)
                        file.prepareForNewUpload()
                        didClearSomething = true
                        Log.info("Cleared revision \(revisionID) for already uploaded file \(fileID)", domain: .storage)
                    }
                }
            return didClearSomething
        }
    }

    func fetchPhotosCount(moc: NSManagedObjectContext) -> Int {
        return moc.performAndWait {
            let fetchRequest = requestPrimaryPhotos()
            return (try? moc.count(for: fetchRequest)) ?? 0
        }
    }

    // MARK: Subscriptions

    func subscriptionToPhotoShares(moc: NSManagedObjectContext) -> NSFetchedResultsController<Share> {
        let request = requestShares()
        request.predicate = NSPredicate(format: "%K == %d", #keyPath(Share.type), Share.ShareType.photos.rawValue)
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
    }

    func subscriptionToUploadingPhotos(moc: NSManagedObjectContext) -> NSFetchedResultsController<Photo> {
        return NSFetchedResultsController(fetchRequest: self.requestUploadingPhotos(),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }
    
    func subscriptionToUploadingFiles() -> NSFetchedResultsController<File> {
        return NSFetchedResultsController(fetchRequest: self.requestUploading(moc: mainContext),
                                          managedObjectContext: mainContext,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }
    
    func subscriptionToRoots(moc: NSManagedObjectContext) -> NSFetchedResultsController<Share> {
        return NSFetchedResultsController(fetchRequest: self.requestShares(),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }
    
    func subscriptionToNodes(share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        return NSFetchedResultsController(fetchRequest: self.requestNodes(share: shareID, sorting: sorting, moc: moc),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: #keyPath(Node.stateRaw),
                                          cacheName: nil)
    }
    
    func subscriptionToChildren(node nodeID: String, share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        let fetchRequest = self.requestChildren(node: nodeID, share: shareID, sorting: sorting, moc: moc)
        return NSFetchedResultsController(fetchRequest: fetchRequest,
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: #keyPath(Node.stateRaw),
                                          cacheName: nil)
    }

    func subscriptionToTrash(moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        return NSFetchedResultsController(fetchRequest: self.requestTrashResult(moc: moc),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }
    
    func subscriptionToOfflineAvailable(withInherited: Bool, moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        return NSFetchedResultsController(fetchRequest: self.requestOfflineAvailable(withInherited: withInherited, moc: moc),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: #keyPath(Node.isFolder), // transient, requires MimeType to be cleartext in DB
                                          cacheName: nil)
    }
    
    func subscriptionToStarred(share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        return NSFetchedResultsController(fetchRequest: self.requestStarred(share: shareID, sorting: sorting, moc: moc),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: #keyPath(Node.stateRaw),
                                          cacheName: nil)
    }
    
    func subscriptionToShared(sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        return NSFetchedResultsController(fetchRequest: self.requestShared(sorting: sorting, moc: moc),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: #keyPath(Node.stateRaw),
                                          cacheName: nil)
    }

    func subscriptionToPrimaryUploadedPhotos(moc: NSManagedObjectContext) -> NSFetchedResultsController<Photo> {
        return NSFetchedResultsController(
            fetchRequest: requestPrimaryUploadedPhotos(),
            managedObjectContext: moc,
            sectionNameKeyPath: #keyPath(Photo.monthIdentifier),
            cacheName: "PhotoFetchCache"
        )
    }

    func subscriptionToThumbnails(moc: NSManagedObjectContext, type: ThumbnailType) -> NSFetchedResultsController<Thumbnail> {
        return NSFetchedResultsController(
            fetchRequest: requestDownloadedThumbnails(type: type),
            managedObjectContext: moc,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    func subscriptionToPrimaryUploadingPhotos(moc: NSManagedObjectContext) -> NSFetchedResultsController<Photo> {
        return NSFetchedResultsController(
            fetchRequest: requestPrimaryUploadingPhotos(),
            managedObjectContext: moc,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
    
    // MARK: Requests

    private func requestDevices() -> NSFetchRequest<Device> {
        let fetchRequest = NSFetchRequest<Device>()
        fetchRequest.entity = Device.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Device.id), ascending: true)]
        return fetchRequest
    }

    private func requestVolumes() -> NSFetchRequest<Volume> {
        let fetchRequest = NSFetchRequest<Volume>()
        fetchRequest.entity = Volume.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Volume.id), ascending: true)]
        return fetchRequest
    }
    
    private func requestSharesOfVolume() -> NSFetchRequest<Share> {
        let fetchRequest = NSFetchRequest<Share>()
        fetchRequest.entity = Share.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Share.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(Share.volume))
        return fetchRequest
    }
    
    private func requestShares() -> NSFetchRequest<Share> {
        let fetchRequest = NSFetchRequest<Share>()
        fetchRequest.entity = Share.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Share.id), ascending: true)]
//        fetchRequest.predicate = NSPredicate(format: "true == %@", true)
        return fetchRequest
    }

    private func requestChildren(node nodeID: String,
                                 share shareID: String,
                                 hash: String? = nil,
                                 includeTrashed: Bool = false,
                                 sorting: SortPreference,
                                 moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.stateRaw), ascending: true),
                                        sorting.descriptor,
                                        .init(key: #keyPath(Node.id), ascending: true)]

        var subpredicates = [NSPredicate]()
        subpredicates.append(NSPredicate(format: "%K == %@ AND %K == %@",
                                             #keyPath(Node.parentLink.id), nodeID,
                                             #keyPath(Node.shareID), shareID))
        if let hash {
            subpredicates.append(NSPredicate(format: "%K == %@",
                                             #keyPath(Node.nodeHash), hash))
        }
        if !includeTrashed {
            subpredicates.append(NSPredicate(format: "%K != %d",
                                             #keyPath(Node.stateRaw), Node.State.deleted.rawValue))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        return fetchRequest
    }
    
    private func requestNode(node nodeID: String, share shareID: String, moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                             #keyPath(Node.id), nodeID,
                                             #keyPath(Node.shareID), shareID)
        return fetchRequest
    }
    
    private func requestDraft(localID: String, share shareID: String, moc: NSManagedObjectContext) -> NSFetchRequest<File> {
        let fetchRequest = NSFetchRequest<File>()
        fetchRequest.entity = File.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.localID), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                             #keyPath(Node.localID), localID,
                                             #keyPath(Node.shareID), shareID)
        return fetchRequest
    }

    private func requestNodesOf(ids: [String], moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
        return fetchRequest
    }
    
    private func requestNodes(share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.stateRaw), ascending: true),
                                        sorting.descriptor,
                                        .init(key: #keyPath(Node.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K != nil",
                                             #keyPath(Node.shareID), shareID,
                                             #keyPath(Node.parentLink)) // this will exclude Root folders from the list
        
        return fetchRequest
    }
    
    private func requestDirtyNodes(share shareID: String, moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.dirtyIndex), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K != %d",
                                             #keyPath(Node.shareID), shareID,
                                             #keyPath(Node.dirtyIndex), 0)
        return fetchRequest
    }
    
    private func requestUploading<Result: NSFetchRequestResult>(moc: NSManagedObjectContext) -> NSFetchRequest<Result> {
        let fetchRequest = NSFetchRequest<Result>()
        fetchRequest.entity = File.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %d OR %K == %d OR %K == %d OR %K == %d",
                                             #keyPath(Node.stateRaw), Node.State.uploading.rawValue,
                                             #keyPath(Node.stateRaw), Node.State.cloudImpediment.rawValue,
                                             #keyPath(Node.stateRaw), Node.State.paused.rawValue,
                                             #keyPath(Node.stateRaw), Node.State.interrupted.rawValue)
        
        return fetchRequest
    }

    private func requestFilesUploading(moc: NSManagedObjectContext) -> NSFetchRequest<File> {
        let fetchRequest = NSFetchRequest<File>()
        fetchRequest.entity = File.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(File.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == %d OR %K == %d OR %K == %d",
            #keyPath(File.stateRaw), File.State.uploading.rawValue,
            #keyPath(File.stateRaw), File.State.cloudImpediment.rawValue,
            #keyPath(File.stateRaw), File.State.interrupted.rawValue
        )

        return fetchRequest
    }

    private func requestFilesInterrupted(moc: NSManagedObjectContext) -> NSFetchRequest<File> {
        let fetchRequest = NSFetchRequest<File>()
        fetchRequest.entity = File.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(File.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == %d",
            #keyPath(File.stateRaw), File.State.interrupted.rawValue
        )
        return fetchRequest
    }

    private func requestTrashResult<Result: NSFetchRequestResult>(moc: NSManagedObjectContext) -> NSFetchRequest<Result> {
        let fetchRequest = NSFetchRequest<Result>()
        fetchRequest.entity = Node.entity()
        let sorting = SortPreference.default
        fetchRequest.sortDescriptors = [sorting.descriptor]
        fetchRequest.predicate = NSPredicate(
            format: "%K == %d AND %K == %d",
            #keyPath(Node.stateRaw), Node.State.deleted.rawValue,
            #keyPath(Node.isToBeDeleted), false
        )
        return fetchRequest
    }
    
    private func requestOfflineAvailable(withInherited: Bool, moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()

        let sorting = SortPreference.modifiedDescending
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Node.mimeType, ascending: true), // real
                                        .init(key: sorting.keyPath, ascending: sorting.isAscending)]
        
        let marked = NSPredicate(format: "%K == TRUE AND %K != %d",
                                 #keyPath(Node.isMarkedOfflineAvailable),
                                 #keyPath(Node.stateRaw), Node.State.deleted.rawValue)
        let inherited = NSPredicate(format: "%K == TRUE", #keyPath(Node.isInheritingOfflineAvailable))
        
        if withInherited {
            fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: [marked, inherited])
        } else {
            fetchRequest.predicate = marked
        }
        return fetchRequest
    }
    
    private func requestStarred<Result: NSFetchRequestResult>(share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchRequest<Result> {
        let fetchRequest = NSFetchRequest<Result>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.stateRaw), ascending: true),
                                        sorting.descriptor,
                                        .init(key: #keyPath(Node.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K != nil AND %K == TRUE",
                                             #keyPath(Node.shareID), shareID,
                                             #keyPath(Node.parentLink),  // this will exclude Root folders from the list
                                             #keyPath(Node.isFavorite))
        return fetchRequest
    }
    
    private func requestShared<Result: NSFetchRequestResult>(sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchRequest<Result> {
        let fetchRequest = NSFetchRequest<Result>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [
            .init(key: #keyPath(Node.stateRaw), ascending: true),
            sorting.descriptor,
            .init(key: #keyPath(Node.id), ascending: true)
        ]
        fetchRequest.predicate = NSPredicate(
            format: "%K != nil AND %K == TRUE",
            #keyPath(Node.parentLink),  // this will exclude Root folders from the list
            #keyPath(Node.isShared)
        )
        return fetchRequest
    }

    private func requestWaitingFiles(maxSize: Int, moc: NSManagedObjectContext) -> NSFetchRequest<File> {
        let fetchRequest = NSFetchRequest<File>()
        fetchRequest.entity = File.entity()
        fetchRequest.sortDescriptors = [.init(key: Node.modifiedDateKeyPath, ascending: true),
                                        .init(key: #keyPath(Node.size), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K < %i AND %K == %d",
                                             #keyPath(Node.size), NSNumber(value: maxSize).intValue,
                                             #keyPath(Node.stateRaw), Node.State.cloudImpediment.rawValue)
        return fetchRequest
    }

    private func requestWaitingPhotos(maxSize: Int, moc: NSManagedObjectContext) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [
            .init(key: Node.modifiedDateKeyPath, ascending: true),
            .init(key: #keyPath(Node.size), ascending: true)
        ]
        fetchRequest.predicate = NSPredicate(
            format: "%K < %i AND %K == %d",
            #keyPath(Node.size), NSNumber(value: maxSize).intValue,
            #keyPath(Node.stateRaw), Node.State.cloudImpediment.rawValue
        )
        return fetchRequest
    }

    private func requestPhotos(ids: [String], moc: NSManagedObjectContext) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
        return fetchRequest
    }

    private func requestPrimaryPhotos() -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "%K == nil", #keyPath(Photo.parent))
        return fetchRequest
    }

    private func requestPrimaryUploadedPhotos(ascending: Bool = false) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [
            .init(key: #keyPath(Photo.captureTime), ascending: ascending),
            .init(key: #keyPath(Photo.id), ascending: false),
        ]
        fetchRequest.predicate = NSPredicate(format: "%K == nil AND %K == %d ",
                                             #keyPath(Photo.parent),
                                             #keyPath(Node.stateRaw), Node.State.active.rawValue)
        return fetchRequest
    }

    private func requestDownloadedThumbnails(type: ThumbnailType) -> NSFetchRequest<Thumbnail> {
        let fetchRequest = NSFetchRequest<Thumbnail>()
        fetchRequest.entity = Thumbnail.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Thumbnail.revision.id), ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "%K.%K != nil AND %K == %d",
                                             #keyPath(Thumbnail.blob), #keyPath(ThumbnailBlob.encrypted),
                                             #keyPath(Thumbnail.type), type.rawValue)
        return fetchRequest
    }

    func requestPhoto(_ id: NodeIdentifier) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Photo.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == %@ AND %K == %@",
            #keyPath(Photo.id), id.nodeID,
            #keyPath(Photo.shareID), id.shareID
        )
        return fetchRequest
    }

    func requestUploadingPhotos() -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == %d OR %K == %d OR %K == %d",
            #keyPath(Photo.stateRaw), Photo.State.uploading.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.cloudImpediment.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.interrupted.rawValue
        )
        return fetchRequest
    }

    private func requestPrimaryUploadingPhotos() -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == nil AND (%K == %d OR %K == %d OR %K == %d OR ANY %K.%K == %d OR ANY %K.%K == %d OR ANY %K.%K == %d)",
            #keyPath(Photo.parent),
            #keyPath(Photo.stateRaw), Photo.State.uploading.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.cloudImpediment.rawValue,
            #keyPath(Photo.stateRaw), Photo.State.interrupted.rawValue,
            #keyPath(Photo.children), #keyPath(Photo.stateRaw), Photo.State.uploading.rawValue,
            #keyPath(Photo.children), #keyPath(Photo.stateRaw), Photo.State.cloudImpediment.rawValue,
            #keyPath(Photo.children), #keyPath(Photo.stateRaw), Photo.State.interrupted.rawValue
        )
        return fetchRequest
    }

    private func requestThumbnail(id: String) -> NSFetchRequest<Thumbnail> {
        let fetchRequest = NSFetchRequest<Thumbnail>()
        fetchRequest.entity = Thumbnail.entity()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }

    private func requestPhotoExists(id: String) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1
        fetchRequest.resultType = .countResultType
        return fetchRequest
    }
}
