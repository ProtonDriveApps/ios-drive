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
import os.log
import PDClient

public class CloudSlot: LogObject {
    public enum Errors: Error, CaseIterable {
        case noSharesAvailable, noRevisionCreated, noNamesApproved, noNodeFound
        case failedToFindBlockKey, failedToFindBlockSignature, failedToFindBlockHash
        case failedToEncryptBlocks
        
        case couldNotFindMainShareForNewShareCreation, couldNotFindVolumeForNewShareCreation
    }

    @FastStorage("lastEventFetchTime-Cloud") public var lastEventFetchTime: Date?
    @FastStorage("lastKnownEventID-Cloud") public var lastScannedEventID: EventID?
    @FastStorage("referenceDate-Cloud") public var referenceDate: Date?

    public static let osLog = OSLog(subsystem: "PDCore", category: "CloudSlot")
    let storage: StorageManager
    let client: Client
    let signersKitFactory: SignersKitFactoryProtocol

    internal var moc: NSManagedObjectContext {
        self.storage.backgroundContext
    }
    
    public init(client: Client, storage: StorageManager, signersKitFactory: SignersKitFactoryProtocol) {
        self.client = client
        self.storage = storage
        self.signersKitFactory = signersKitFactory
    }

    private func updateShare(shareMeta: ShareMeta, handler: @escaping (Result<Share, Error>) -> Void) {
        self.moc.performAndWait {
            let updatedShare = self.update(shareMeta, in: self.moc)
            do {
                try self.moc.save()
                handler(.success(updatedShare))
            } catch {
                return handler(.failure(error))
            }
        }
    }
    
    // MARK: - SCAN CLOUD
    public func scanVolumes(handler: @escaping (Result<[Volume], Error>) -> Void) {
        self.client.getVolumes { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let volumesMeta):
                self.moc.performAndWait {
                    let objs = self.update(volumesMeta, in: self.moc)
                    do {
                        try self.moc.save()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }
    
    public func scanRoots(onFoundMainShare: @escaping (Result<Share, Error>) -> Void,
                          onMainShareNotFound: @escaping () -> Void)
    {
        client.getVolumes { [weak self] result in
            switch result {
            case .failure(let error): onFoundMainShare(.failure(error))
            case .success(let volumes):
                guard let volume = volumes.first(where: { $0.state == .active }) else {
                    return onMainShareNotFound()
                }
                self?.scanMainShare(shareID: volume.share.shareID, handler: onFoundMainShare)
            }
        }
    }
    
    public func scanShare(shareID: String, handler: @escaping (Result<Share, Error>) -> Void) {
        self.client.getShare(shareID) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let shareMeta): self.updateShare(shareMeta: shareMeta, handler: handler)
            }
        }
    }
    
    public func scanMainShare(shareID: String, handler: @escaping (Result<Share, Error>) -> Void) {
        self.client.getShare(shareID) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let shareMeta):
                let rootNodeIdentifier = NodeIdentifier(shareMeta.linkID, shareMeta.shareID)
                self.scanNode(rootNodeIdentifier) { result in
                    switch result {
                    case .failure(let error): handler(.failure(error))
                    case .success: self.updateShare(shareMeta: shareMeta, handler: handler)
                    }
                }
            }
        }
    }
    
    public func scanShareURL(shareID: String, handler: @escaping (Result<[ShareURL], Error>) -> Void) {
        self.client.getShareUrl(shareID) { [moc] result in
            switch result {
            case let .failure(error): handler(.failure(error))
            case let .success(shareUrlsMeta):
                moc.performAndWait {
                    let objs = self.update(shareUrlsMeta, in: moc)
                    
                    do {
                        try moc.save()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }
    
    public func scanAllShareURLs(ofMainShare shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<[ShareURL], Error>) -> Void) {
        self.client.getShareUrlRecursively(shareID, page: page, pageSize: size) { [moc] result in
            switch result {
            case let .failure(error): handler(.failure(error))
            case let .success((links, shareUrlsMeta)):
                moc.performAndWait {
                    let _ = self.update(links, of: shareID, in: moc)
                    let objs = self.update(shareUrlsMeta, in: moc)
                    
                    do {
                        try moc.save()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }
    
    public func scanChildren(of parentID: NodeIdentifier,
                             parameters: [FolderChildrenEndpointParameters]? = nil,
                             handler: @escaping (Result<[Node], Error>) -> Void)
    {
        let mode: UpdateMode = (parameters?.containsPagination() ?? false) ? .append : .replace
        self.client.getFolderChildren(parentID.shareID, folderID: parentID.nodeID, parameters: parameters) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let childrenLinksMeta):
                self.moc.performAndWait {
                    let objs = self.update(childrenLinksMeta, under: parentID.nodeID, of: parentID.shareID, mode: mode, in: self.moc)
                    do {
                        try self.moc.save()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }
    
    public func scanNode(_ nodeID: NodeIdentifier,
                         handler: @escaping (Result<Node, Error>) -> Void)
    {
        self.client.getNode(nodeID.shareID, nodeID: nodeID.nodeID) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let linkMeta):
                self.moc.performAndWait {
                    let objs = self.update([linkMeta], of: nodeID.shareID, in: self.moc)
                    do {
                        try self.moc.save()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs.first!))
                }
            }
        }
    }
    
    public func scanRevision(_ revisionID: RevisionIdentifier,
                             handler: @escaping (Result<Revision, Error>) -> Void)
    {
        self.client.getRevision(revisionID.share, fileID: revisionID.file, revisionID: revisionID.revision) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let revisionMeta):
                self.moc.performAndWait {
                    let obj = self.update(revisionMeta, inFileID: revisionID.file, of: revisionID.share, in: self.moc)
                    do {
                        try self.moc.saveOrRollback()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(obj))
                }
            }
        }
    }
    
    // MARK: MAP FROM DB
    /* 🆅 Cloud will not be interested in DB contents on its own */
    
    // MARK: - SUBSCRIBE TO DB CHANGES
    /* 🆅 Cloud will not be interested in DB contents on its own */
    
    // MARK: - SEND FROM CLOUD TO DB
    
    /* Send event to the local db derived from cloud events */

    // MARK: - SEND FROM DB TO CLOUD
    func deleteNodeInFolder(shareID: String, folderID: String, nodeIDs: [String], completion: @escaping Outcome) {
        client.deleteLinkInFolderPermanently(shareID: shareID, folderID: folderID, linkIDs: nodeIDs, completion: completion)
    }
}

public protocol TrashScanner {
    func scanTrashed(shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<Int, Error>) -> Void)
}

extension CloudSlot: TrashScanner {
    public func scanTrashed(shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<Int, Error>) -> Void) {
        client.getTrash(shareID: shareID, page: page, pageSize: size) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let links):
                self.moc.performAndWait {
                    self.update(links.parents, of: shareID, in: self.moc)
                    self.update(links.trash, of: shareID, in: self.moc)
                    do {
                        try self.moc.save()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(links.trash.count))
                }
            case .failure(let error): handler(.failure(error))
            }
        }
    }
}

extension CloudSlot.Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noSharesAvailable: return "This account has no shares"
        case .noRevisionCreated: return "No file revisions created"
        case .noNamesApproved: return "None of file names is allowed"
        case .noNodeFound: return "Node not found"
        case .failedToEncryptBlocks, .failedToFindBlockKey, .failedToFindBlockHash, .failedToFindBlockSignature: return "Failed to encrypt block"
        case .couldNotFindMainShareForNewShareCreation:
            return "Failed to share node that is not part of Volume"
        case .couldNotFindVolumeForNewShareCreation:
            return "Failed to share node because could not find Volume"
        }
    }
}
