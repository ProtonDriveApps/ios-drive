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
import ProtonCoreUtilities

public class CloudSlot {
    public enum Errors: Error, CaseIterable {
        case noSharesAvailable, noRevisionCreated, noNamesApproved, noNodeFound
        case failedToFindBlockKey, failedToFindBlockSignature, failedToFindBlockHash
        case failedToEncryptBlocks
        
        case couldNotFindMainShareForNewShareCreation, couldNotFindVolumeForNewShareCreation
    }
    
    public typealias NoShare = Void

    let storage: StorageManager
    let client: Client
    let sessionVault: SessionVault

    internal var moc: NSManagedObjectContext {
        self.storage.backgroundContext
    }

    let queue = DispatchQueue.global(qos: .default)
    
    private let instanceIdentifier = UUID()
    
    public init(client: Client, storage: StorageManager, sessionVault: SessionVault) {
        self.client = client
        self.storage = storage
        self.sessionVault = sessionVault
        Log.info("CloudSlot init: \(instanceIdentifier)", domain: .syncing)
    }
    
    deinit {
        Log.info("CloudSlot deinit: \(instanceIdentifier)", domain: .syncing)
    }
    
    var signersKitFactory: SignersKitFactoryProtocol {
        sessionVault
    }

    private func makeSupportedSharesValidator() -> SupportedSharesValidator {
        #if os(iOS)
        return iOSSupportedSharesValidator(storage: storage)
        #else
        return macOSSupportedSharesValidator()
        #endif
    }

    private func updateShare(shareMeta: ShareMeta, handler: @escaping (Result<Share, Error>) -> Void) {
        self.moc.performAndWait {
            let updatedShare = self.update(shareMeta, in: self.moc)
            do {
                try self.moc.saveWithParentLinkCheck()
                handler(.success(updatedShare))
            } catch {
                return handler(.failure(error))
            }
        }
    }
    
    // MARK: - SCAN CLOUD
    public func scanShare(shareID: String, handler: @escaping (Result<Share, Error>) -> Void) {
        self.client.getShare(shareID) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let shareMeta):
                self.updateShare(shareMeta: shareMeta, handler: handler)
            }
        }
    }

    public func scanRoots(isPhotosEnabled: Bool = false, onFoundMainShare: @escaping (Result<Share, Error>) -> Void, onMainShareNotFound: @escaping () -> Void) {
        Task {
            do {
                guard let mainShare = try await scanRootsAsync() else {
                    onMainShareNotFound()
                    return
                }
                await MainActor.run {
                    onFoundMainShare(.success(mainShare))
                }
            } catch {
                await MainActor.run {
                    onFoundMainShare(.failure(error))
                }
            }
        }
    }
    
    public func scanRootsAsync(isPhotosEnabled: Bool = false) async throws -> Share? {
        // we cannot rely on volume state being properly updated before we call for shares first.
        // call for shares updates the volume state as a hidden side effect. this is a BE quirk.
        _ = try await client.getShares()
        
        let volumes = try await client.getVolumes()

        guard let volume = volumes.first(where: { $0.state == .active }) else {
            return nil
        }

        let mainShare = try await scanRootShare(volume.share.shareID)
        if isPhotosEnabled {
            do {
                let photosShare = try await client.listPhotoShares()
                _ = try await scanRootShare(photosShare.shareID)
            } catch { }
        }
        
        return mainShare
    }

    func scanRootShare(_ shareID: String) async throws -> Share {
        try await withCheckedThrowingContinuation { continuation in
            scanShareAndRootFolder(shareID: shareID, handler: continuation.resume(with:))
        }
    }

    public func scanShareAndRootFolder(shareID: String, handler: @escaping (Result<Share, Error>) -> Void) {
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
                        try moc.saveWithParentLinkCheck()
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
                    _ = self.update(links, of: shareID, in: moc)
                    let objs = self.update(shareUrlsMeta, in: moc)
                    
                    do {
                        try moc.saveWithParentLinkCheck()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }

    public func scanAllShareURL(volumeID: String) async throws {
        try await fetchShareURLs(volumeID, atPage: 0)
    }

    private func fetchShareURLs(_ volumeID: String, atPage page: Int) async throws {
        let pageSize = Constants.pageSizeForRefreshes
        do {
            let response = try await client.getShareUrl(volumeID: volumeID, page: page, pageSize: pageSize)
            Log.info("Fetched Trash – Page: \(page), Items: \(response)", domain: .networking)
            let supportedSharesValidator = makeSupportedSharesValidator()
            
            for context in response.shareURLContexts {
                guard supportedSharesValidator.isValid(context.contextShareID),
                      !context.linkIDs.isEmpty else {
                    continue
                }
                
                try await fetchAllLinksInGroups(context.linkIDs, context.contextShareID)
            }

            let shareURLs = response.shareURLContexts.reduce([]) { $0 + $1.shareURLs }
            try await moc.perform { [weak self] in
                guard let self else { return }
                _ = self.update(shareURLs, in: self.moc)
                try self.moc.saveOrRollback()
            }

            guard response.more else { return }
            try await fetchShareURLs(volumeID, atPage: page + 1)
        } catch {
            throw error
        }
    }

    func fetchAllLinksInGroups(_ links: [String], _ shareID: String) async throws {
        let linksGroups = links.splitInGroups(of: 150)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for linkGroup in linksGroups {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    do {
                        let linksResponse = try await self.client.getLinksMetadata(with: .init(shareId: shareID, linkIds: linkGroup))
                        _ = try self.update(links: linksResponse.parents + linksResponse.links, shareId: shareID, managedObjectContext: self.moc)
                    } catch {
                        throw error
                    }
                }
            }

            for try await _ in group { }
        }
    }

    public func scanAllTrashed(volumeID: String) async throws {
        try await fetchTrash(volumeID, atPage: 0)
    }

    private func fetchTrash(_ volumeID: String, atPage page: Int) async throws {
        let pageSize = Constants.pageSizeForRefreshes
        do {
            let response = try await client.listVolumeTrash(volumeID: volumeID, page: page, pageSize: pageSize)
            let supportedSharesValidator = makeSupportedSharesValidator()
            
            for batch in response.trash {
                guard supportedSharesValidator.isValid(batch.shareID),
                      !batch.linkIDs.isEmpty else {
                    continue
                }
                
                do {
                    let linksResponse = try await client.getLinksMetadata(with: .init(shareId: batch.shareID, linkIds: batch.linkIDs))
                    try await moc.perform { [weak self] in
                        guard let self else { return }
                        _ = try self.update(links: linksResponse.parents + linksResponse.links, shareId: batch.shareID, managedObjectContext: self.moc)
                        try self.moc.saveOrRollback()
                    }
                } catch {
                    throw error
                }
            }

            guard !response.trash.isEmpty else { return }
            try await fetchTrash(volumeID, atPage: page + 1)
        } catch {
            throw error
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
                    let childrenLinksMetaWithoutDrafts = childrenLinksMeta.filter { $0.state != .draft }
                    let objs = self.update(childrenLinksMetaWithoutDrafts, under: parentID.nodeID, of: parentID.shareID, mode: mode, in: self.moc)
                    do {
                        try self.moc.saveWithParentLinkCheck()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }
    
    public func scanNode(_ nodeID: NodeIdentifier,
                         linkProcessingErrorTransformer: @escaping (Link, Error) -> Error = { $1 },
                         handler: @escaping (Result<Node, Error>) -> Void)
    {
        self.client.getNode(nodeID.shareID, nodeID: nodeID.nodeID, breadcrumbs: .startCollecting()) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let linkMeta):
                self.moc.performAndWait {
                    let objs = self.update([linkMeta], of: nodeID.shareID, in: self.moc)
                    do {
                        try self.moc.saveWithParentLinkCheck()
                    } catch let error {
                        self.moc.rollback()
                        return handler(.failure(linkProcessingErrorTransformer(linkMeta, error)))
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

    // MARK: - SEND FROM DB TO CLOUD
    func deleteNodeInFolder(shareID: String, folderID: String, nodeIDs: [String], completion: @escaping Outcome) {
        client.deleteLinkInFolderPermanently(shareID: shareID, folderID: folderID, linkIDs: nodeIDs, completion: completion)
    }
}

// MARK: - Delete Uploading files
public protocol CloudFileCleaner {
    func deleteUploadingFile(linkId: String, parentId: String, shareId: String, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteUploadingFile(shareId: String, parentId: String, linkId: String) async throws
}

enum CloudFileCleanerError: Error {
    case fileIsNotADraft
}

extension CloudSlot: CloudFileCleaner {
    public func deleteUploadingFile(linkId: String, parentId: String, shareId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.deleteNodeInFolder(shareID: shareId, folderID: parentId, nodeIDs: [linkId], completion: completion)
    }

    public func deleteUploadingFile(shareId: String, parentId: String, linkId: String) async throws {
        let link = try await client.getLink(shareID: shareId, linkID: linkId, breadcrumbs: .startCollecting())

        guard link.state == .draft else {
            throw CloudFileCleanerError.fileIsNotADraft
        }

        _ = try await client.deleteChildren(shareID: shareId, folderID: parentId, linkIDs: [linkId])
    }
}

public protocol TrashScanner {
    func scanTrashed(shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<[Node], Error>) -> Void)
}

extension CloudSlot: TrashScanner {
    public func scanTrashed(shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<[Node], Error>) -> Void) {
        client.getTrash(shareID: shareID, page: page, pageSize: size) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let links):
                self.moc.performAndWait {
                    self.update(links.parents, of: shareID, in: self.moc)
                    let nodes = self.update(links.trash, of: shareID, in: self.moc)
                    do {
                        try self.moc.saveWithParentLinkCheck()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(nodes))
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

// MARK: - Temporary workaround to filter non suported shares
import Combine
protocol SupportedSharesValidator {
    func isValid(_ id: String) -> Bool
}
class iOSSupportedSharesValidator: SupportedSharesValidator {
    private let storage: StorageManager
    
    private lazy var supportedShares: Set<String> = {
        let moc = storage.backgroundContext
        let shareIds = moc.performAndWait {
            do {
                let shares = try storage.fetchSupportedShares(moc: moc)
                return shares.map(\.id)
            } catch {
                return []
            }
        }
        return Set(shareIds)
    }()

    init(storage: StorageManager) {
        self.storage = storage
    }

    func isValid(_ id: String) -> Bool {
        supportedShares.contains(id)
    }
}
class macOSSupportedSharesValidator: SupportedSharesValidator {
    func isValid(_ id: String) -> Bool {
        true
    }
}
