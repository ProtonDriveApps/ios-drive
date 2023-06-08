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
    
    func fetchChildren(of parentID: String,
                       share shareID: String,
                       sorting: SortPreference,
                       moc: NSManagedObjectContext) throws -> [Node]
    {
        let fetchRequest = self.requestChildren(node: parentID, share: shareID, sorting: sorting, moc: moc)
        return try moc.fetch(fetchRequest)
    }
    
    func fetchNode(id: NodeIdentifier, moc: NSManagedObjectContext) -> Node? {
        var node: Node?
        moc.performAndWait {
            let fetchRequest = self.requestNode(node: id.nodeID, share: id.shareID, moc: moc)
            node = try? moc.fetch(fetchRequest).first
        }
        return node
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
    
    func fetchWaiting(maxSize: Int, moc: NSManagedObjectContext) -> [File] {
        var files = [File]()
        moc.performAndWait {
            let fetchRequest = self.requestWaiting(maxSize: maxSize, moc: moc)
            files = (try? moc.fetch(fetchRequest)) ?? []
        }
        return files
    }

    func fetchPrimaryPhotos(moc: NSManagedObjectContext) -> [Photo] {
        return moc.performAndWait {
            let fetchRequest = requestPhotos(moc: moc)
            return (try? moc.fetch(fetchRequest)) ?? []
        }
    }

    func fetchPhoto(id: NodeIdentifier, moc: NSManagedObjectContext) -> Photo? {
        return moc.performAndWait {
            let fetchRequest = requestPhoto(id: id)
            return try? moc.fetch(fetchRequest).first
        }
    }
    
    // Subscriptions

    func subscriptionToPhotoDevices() -> NSFetchedResultsController<Device> {
        let request = requestDevices()
        request.predicate = NSPredicate(format: "%K == %d", #keyPath(Device.type), Device.´Type´.photos.rawValue)
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: backgroundContext, sectionNameKeyPath: nil, cacheName: nil)
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
    
    func subscriptionToShared(share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchedResultsController<Node> {
        return NSFetchedResultsController(fetchRequest: self.requestShared(share: shareID, sorting: sorting, moc: moc),
                                          managedObjectContext: moc,
                                          sectionNameKeyPath: #keyPath(Node.stateRaw),
                                          cacheName: nil)
    }

    func subscriptionToPhotos(moc: NSManagedObjectContext) -> NSFetchedResultsController<Photo> {
        return NSFetchedResultsController(
            fetchRequest: requestPhotos(moc: moc),
            managedObjectContext: moc,
            sectionNameKeyPath: #keyPath(Photo.monthIdentifier),
            cacheName: "PhotoFetchCache"
        )
    }

    func subscriptionToThumbnails(moc: NSManagedObjectContext) -> NSFetchedResultsController<Thumbnail> {
        return NSFetchedResultsController(
            fetchRequest: requestThumbnails(),
            managedObjectContext: moc,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
    
    // Requests
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
    
    private func requestChildren(node nodeID: String, share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.stateRaw), ascending: true),
                                        sorting.descriptor,
                                        .init(key: #keyPath(Node.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K != %d",
                                             #keyPath(Node.parentLink.id), nodeID,
                                             #keyPath(Node.shareID), shareID,
                                             #keyPath(Node.stateRaw), Node.State.deleted.rawValue)
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
        fetchRequest.predicate = NSPredicate(format: "%K == %d AND %K == %d",
                                             #keyPath(Node.stateRaw), Node.State.deleted.rawValue,
                                             #keyPath(Node.isToBeDeleted), false)
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
    
    private func requestShared<Result: NSFetchRequestResult>(share shareID: String, sorting: SortPreference, moc: NSManagedObjectContext) -> NSFetchRequest<Result> {
        let fetchRequest = NSFetchRequest<Result>()
        fetchRequest.entity = Node.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.stateRaw), ascending: true),
                                        sorting.descriptor,
                                        .init(key: #keyPath(Node.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K != nil AND %K == TRUE",
                                             #keyPath(Node.shareID), shareID,
                                             #keyPath(Node.parentLink),  // this will exclude Root folders from the list
                                             #keyPath(Node.isShared))
        return fetchRequest
    }
    
    private func requestWaiting(maxSize: Int, moc: NSManagedObjectContext) -> NSFetchRequest<File> {
        let fetchRequest = NSFetchRequest<File>()
        fetchRequest.entity = File.entity()
        fetchRequest.sortDescriptors = [.init(key: Node.modifiedDateKeyPath, ascending: true),
                                        .init(key: #keyPath(Node.size), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K < %i AND %K == %d",
                                             #keyPath(Node.size), NSNumber(value: maxSize).intValue,
                                             #keyPath(Node.stateRaw), Node.State.cloudImpediment.rawValue)
        return fetchRequest
    }

    private func requestPhotos(moc: NSManagedObjectContext) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Photo.timestamp), ascending: false)]
        // Will return only primary photos
        fetchRequest.predicate = NSPredicate(format: "%K == nil", #keyPath(Photo.parent))
        return fetchRequest
    }

    private func requestThumbnails() -> NSFetchRequest<Thumbnail> {
        let fetchRequest = NSFetchRequest<Thumbnail>()
        fetchRequest.entity = Thumbnail.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Thumbnail.revision.id), ascending: false)]
        return fetchRequest
    }

    private func requestPhoto(id: NodeIdentifier) -> NSFetchRequest<Photo> {
        let fetchRequest = NSFetchRequest<Photo>()
        fetchRequest.entity = Photo.entity()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Photo.id), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                             #keyPath(Photo.id), id.nodeID,
                                             #keyPath(Photo.shareID), id.shareID)
        return fetchRequest
    }
}
