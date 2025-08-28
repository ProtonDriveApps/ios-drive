// Copyright (c) 2024 Proton AG
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
import PDClient
import CoreData

class VolumeDBCloudSlot: CloudSlotProtocol {
    
    private let storage: StorageManager
    private let apiService: APIService
    private let client: PDClient.Client
    private let cloudSlot: CloudSlotProtocol
    weak var downloader: DownloaderProtocol?

    var moc: NSManagedObjectContext { storage.backgroundContext }

    init(
        storage: StorageManager,
        apiService: APIService,
        client: PDClient.Client,
        cloudSlot: CloudSlotProtocol
    ) {
        self.storage = storage
        self.apiService = apiService
        self.client = client
        self.cloudSlot = cloudSlot
    }

    func set(downloader: DownloaderProtocol) {
        self.downloader = downloader
    }

    func scanShare(shareID: String, handler: @escaping (Result<Share, any Error>) -> Void) {
        fatalError("Just used by macOS")
    }

    func scanRoots(isPhotosEnabled: Bool, onFoundMainShare: @escaping (Result<Share, any Error>) -> Void, onMainShareNotFound: @escaping () -> Void) {
        fatalError("Just used by macOS")
    }

    func scanRootsAsync(isPhotosEnabled: Bool) async throws -> Share? {
        fatalError("Just used by macOS")
    }

    func scanShareAndRootFolder(shareID: String, handler: @escaping (Result<Share, any Error>) -> Void) {
        fatalError("Just used by macOS")
    }

    func scanAllTrashed(volumeID: String) async throws {
        let scanner = TrashScanner(client: client, storage: storage, myVolume: volumeID)
        try await scanner.scanTrash()
    }

    func scanChildren(of parentID: NodeIdentifier, parameters: [PDClient.FolderChildrenEndpointParameters]?, handler: @escaping (Result<[Node], any Error>) -> Void) {
        let context = moc
        let mode: CloudSlot.UpdateMode = (parameters?.containsPagination() ?? false) ? .append : .replace

        self.client.getFolderChildren(parentID.shareID, folderID: parentID.nodeID, parameters: parameters) { result in
            switch result {
            case .success(let childrenLinksMeta):
                let childrenLinksMetaWithoutDrafts = childrenLinksMeta.filter { $0.state != .draft }

                context.performAndWait {
                    do {
                        let children = self.storage.updateLinks(childrenLinksMetaWithoutDrafts, in: context)
                        let parent = Folder.fetchOrCreate(identifier: AnyVolumeIdentifier(id: parentID.nodeID, volumeID: parentID.volumeID), in: context)

                        switch mode {
                        case .replace:
                            parent.children = Set(children)
                        case .append:
                            parent.children.formUnion(Set(children))
                        }
                        try context.saveOrRollback()
                        handler(.success(children))
                    } catch {
                        return handler(.failure(error))
                    }
                }

            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    func scanChildren(
        of parentID: NodeIdentifier,
        parameters: [PDClient.FolderChildrenEndpointParameters]?
    ) async throws -> [Node] {
        let context = moc
        let mode: CloudSlot.UpdateMode = (parameters?.containsPagination() ?? false) ? .append : .replace
        
        let childrenLinksMeta = try await client.getFolderChildren(
            parentID.shareID,
            folderID: parentID.nodeID,
            parameters: parameters
        )
        let childrenLinksMetaWithoutDrafts = childrenLinksMeta.filter { $0.state != .draft }
        return try await context.perform { [weak self] in
            guard let self else { return [] }
            let children = self.storage.updateLinks(childrenLinksMetaWithoutDrafts, in: context)
            let parent = Folder.fetchOrCreate(
                identifier: AnyVolumeIdentifier(id: parentID.nodeID, volumeID: parentID.volumeID),
                in: context
            )

            switch mode {
            case .replace:
                parent.children = Set(children)
            case .append:
                parent.children.formUnion(Set(children))
            }
            try context.saveOrRollback()
            return children
        }
    }

    func scanNode(_ nodeID: NodeIdentifier, linkProcessingErrorTransformer: @escaping (PDClient.Link, any Error) -> any Error, handler: @escaping (Result<Node, any Error>) -> Void) {
        // Check in depth
        Task {
            do {
                let node = try await scanNode(nodeID, linkProcessingErrorTransformer: linkProcessingErrorTransformer)
                self.moc.performAndWait {
                    handler(.success(node))
                }
            } catch {
                handler(.failure(error))
            }
        }
    }

    func scanNode(_ nodeID: NodeIdentifier, linkProcessingErrorTransformer: @escaping (Link, Error) -> Error) async throws -> Node {
        let scanner = NodeScanner(client: client, storage: storage)
        try await scanner.scanNode(nodeID)
        let context = self.moc
        // There are a lot of crashes in the Downloader if not done like this
        return try await context.perform {
            try Node.fetchOrThrow(identifier: nodeID, allowSubclasses: true, in: context)
        }
    }
    
    func scanRevision(_ revisionID: RevisionIdentifier) async throws -> Revision {
        let identifier = revisionID
        let scanner = RevisionScanner(client: client, storage: storage)
        try await scanner.scanRevision(identifier)
        let context = self.moc
        // There are a lot of crashes in the Downloader if not done like this
        return try await context.perform {
            try Revision.fetchOrThrow(identifier: identifier, allowSubclasses: true, in: context)
        }
    }

    func scanRevision(_ revisionID: RevisionIdentifier, handler: @escaping (Result<Revision, any Error>) -> Void) {
        let identifier = revisionID
        Task {
            do {
                let scanner = RevisionScanner(client: client, storage: storage)
                try await scanner.scanRevision(identifier)
                let context = self.moc
                // There are a lot of crashes in the Downloader if not done like this
                let revision: Revision = try await context.perform { try Revision.fetchOrThrow(identifier: identifier, allowSubclasses: true, in: context) }
                context.performAndWait {
                    handler(.success(revision))
                }
            } catch {
                handler(.failure(error))
            }
        }
    }

    func deleteUploadingFile(linkId: String, parentId: String, shareId: String, completion: @escaping (Result<Void, any Error>) -> Void) {
        // No modification of the local state, safe to keep
        cloudSlot.deleteUploadingFile(linkId: linkId, parentId: parentId, shareId: shareId, completion: completion)
    }

    func deleteUploadingFile(shareId: String, parentId: String, linkId: String) async throws {
        // Used by macOS and the iOS file uploader, does not need migration because does not modify the local state
        try await cloudSlot.deleteUploadingFile(shareId: shareId, parentId: parentId, linkId: linkId)
    }

    func createFolder(_ name: String, parent: Folder) async throws -> Folder {
        try await cloudSlot.createFolder(name, parent: parent)
    }

    func rename(_ node: Node, to newName: String, mimeType: String?) async throws {
        try await cloudSlot.rename(node, to: newName, mimeType: mimeType)
    }

    func move(node: Node, to newParent: Folder, name: String) async throws {
        try await cloudSlot.move(node: node, to: newParent, name: name)
    }

    func fetchInitialEvent(ofVolumeID volumeID: String) async throws -> EventID {
        try await cloudSlot.fetchInitialEvent(ofVolumeID: volumeID)
    }

    func scanEventsFromRemote(ofVolumeID volumeID: String, since loopEventID: EventID) async throws -> PDClient.EventsEndpoint.Response {
        try await cloudSlot.scanEventsFromRemote(ofVolumeID: volumeID, since: loopEventID)
    }

    func downloadThumbnailURL(parameters: PDClient.RevisionThumbnailParameters, completion: @escaping (Result<URL, any Error>) -> Void) {
        cloudSlot.downloadThumbnailURL(parameters: parameters, completion: completion)
    }

    func createVolumeAsync(signersKit: SignersKit) async throws -> Share {
        fatalError("Just used by macOS")
    }

    func createNewFileDraft(_ draft: UploadableFileDraft, completion: @escaping CloudFileDraftCreatorCompletion) {
        cloudSlot.createNewFileDraft(draft, completion: completion)
    }

    func checkAvailableHashes(among nameHashPairs: [NameHashPair], onFolder folder: NodeIdentifier, completion: @escaping AvailableHashCheckerCompletion) {
        cloudSlot.checkAvailableHashes(among: nameHashPairs, onFolder: folder, completion: completion)
    }

    func create(from revision: UploadableRevision, onCompletion: @escaping CloudContentCreatorCompletion) {
        cloudSlot.create(from: revision, onCompletion: onCompletion)
    }

    func commit(_ revision: CommitableRevision, completion: @escaping (Result<Void, any Error>) -> Void) {
        cloudSlot.commit(revision, completion: completion)
    }

    func checkUploadedRevision(_ id: RevisionIdentifier, completion: @escaping (Result<XAttrs, any Error>) -> Void) {
        cloudSlot.checkUploadedRevision(id, completion: completion)
    }

    func createRevision(for file: NodeIdentifier, onCompletion: @escaping (Result<RevisionIdentifier, any Error>) -> Void) {
        cloudSlot.createRevision(for: file, onCompletion: onCompletion)
    }

    func update(_ links: [LinkMeta], of shareID: ShareMeta.ShareID, in moc: NSManagedObjectContext) -> [NodeObj] {
        var nodes: [Node] = []
        for link in links {
            let node = storage.updateLink(link, using: moc)
            nodes.append(node)
        }
        return nodes
    }

    func update(links: [PDClient.Link], shareId: String, managedObjectContext: NSManagedObjectContext) throws {
        try managedObjectContext.performAndWait {
            for link in links {
                storage.updateLink(link, using: managedObjectContext)
            }
            try managedObjectContext.saveOrRollback()
        }
    }

    func trash(_ nodes: [TrashingNodeIdentifier]) async throws {
        let trasher = NodeTrasher(client: client, storage: storage, downloader: downloader)
        try await trasher.trash(nodes)
    }

    func trashVolume(nodeIDs: [AnyVolumeIdentifier]) async throws {
        let localTrasher = LocalNodeTrasher(context: storage.backgroundContext)
        let trasher = VolumeNodeTrasher(client: client, localTrasher: localTrasher)
        try await trasher.trash(ids: nodeIDs)
    }

    func trash(shareID: Client.ShareID, parentID: Client.LinkID, linkIDs: [Client.LinkID]) async throws {
        fatalError("Not to be used, addressed in tower at the moment")
    }

    func delete(shareID: PDClient.Client.ShareID, linkIDs: [PDClient.Client.LinkID]) async throws {
        fatalError("Not to be used")
    }

    func emptyTrash(shareID: PDClient.Client.ShareID) async throws {
        fatalError("Not to be used")
    }

    func restore(shareID: PDClient.Client.ShareID, linkIDs: [PDClient.Client.LinkID]) async throws -> [PDClient.PartialFailure] {
        fatalError("Not to be used")
    }

    func removeMember(shareID: String, memberID: String) async throws {
        try await client.removeMember(shareID: shareID, memberID: memberID)
    }

    func update(thumbnails: [ThumbnailURL]) throws {
        let context = moc
        let thumbnailsDictionary = Dictionary(uniqueKeysWithValues: thumbnails.map { (AnyVolumeIdentifier(id: $0.id, volumeID: $0.volumeID), $0.url.absoluteString) })
        let identifiers = Set(thumbnailsDictionary.keys)

        try context.performAndWait {
            let thumbnails: [Thumbnail] = Thumbnail.fetch(identifiers: identifiers, in: context)
            for thumbnail in thumbnails {
                guard let url = thumbnailsDictionary[AnyVolumeIdentifier(id: thumbnail.id, volumeID: thumbnail.volumeID)] else {
                    continue
                }
                guard thumbnail.downloadURL != url else {
                    continue
                }
                thumbnail.downloadURL = url
            }
            try context.saveOrRollback()
        }
    }
}
