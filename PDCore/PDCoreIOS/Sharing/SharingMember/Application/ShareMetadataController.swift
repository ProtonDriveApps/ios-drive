// Copyright (c) 2025 Proton AG
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

import Combine
import CoreData
import Foundation
import PDClient
import PDCore

struct DirectShareMetadata {
    let share: PDClient.Share
    let rootNodeKey: DecryptionKey
    let contextShareAddressID: String
}

protocol ShareMetadataProvider {
    var isPublicLinkEnabled: Bool { get }
    var itemName: String { get }
    var nodeIdentifier: NodeIdentifier { get }
    var shareID: String? { get }
    var editorsCanShare: Bool { get }
    var updatePublisher: AnyPublisher<Void, Never> { get }

    func getShareLink() throws -> SharedLink?
    func getDirectShare() async throws -> DirectShareMetadata
    func fetchShareMetaData() async throws -> DirectShareMetadata
    func setEditorsCanShare(_ enabled: Bool)
}

final class ShareMetadataController: ShareMetadataProvider {
    let nodeIdentifier: NodeIdentifier
    private let dependencies: Dependencies
    private var cancellable: AnyCancellable?
    private var node: Node?
    private var observer: FetchedResultsControllerObserver<Node>?
    private(set) var isPublicLinkEnabled: Bool = false
    private(set) var itemName: String = ""
    private(set) var shareID: String?
    private(set) var editorsCanShare = false
    private let updateSubject = PassthroughSubject<Void, Never>()
    
    var updatePublisher: AnyPublisher<Void, Never> {
        updateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    init(
        dependencies: Dependencies,
        nodeIdentifier: NodeIdentifier
    ) {
        self.dependencies = dependencies
        self.nodeIdentifier = nodeIdentifier
        start()
    }

    private func start() {
        let observer = makeObserver()
        self.observer = observer
        cancellable = observer.getPublisher()
            .sink { [weak self] nodes in
                guard let self, let first = nodes.first else { return }
                self.node = first
                self.handleNodeUpdate(first)
            }
    }

    func getShareLink() throws -> SharedLink? {
        return try node?.managedObjectContext?.performAndWait {
            guard let shareURLObj = node?.directShares.first?.shareUrls.first else { return nil }
            let sharedLink = try SharedLink(shareURL: shareURLObj)
            return sharedLink
        }
    }

    func getDirectShare() async throws -> DirectShareMetadata {
        guard let node else { throw ShareMetadataErrors.nodeIsMissing }
        do {
            let directShare: DirectShareMetadata? = try await dependencies.managedObjectContext.perform {
                guard let standardShare = node.getStandardShare() else {
                    return nil
                }
                let linkID = standardShare.linkID ?? standardShare.root?.id ?? node.findRootNode().id
                return try self.mapping(coreDataShare: standardShare, linkID: linkID)
            }
            guard let directShare else { throw ShareMetadataErrors.directShareIsMissing }
            return directShare
        } catch ShareMetadataErrors.needToFetchShareMetadata {
            do {
                return try await fetchShareMetaData()
            } catch ShareMetadataErrors.shareRemovedRemotely {
                return try await createShare()
            }
        } catch ShareMetadataErrors.directShareIsMissing {
            let directShare = try await createShare()
            return directShare
        } catch {
            throw error
        }
    }

    func setEditorsCanShare(_ enabled: Bool) {
        editorsCanShare = enabled
        dependencies.managedObjectContext.performAndWait {
            guard let shareID, let share = Share.fetch(id: shareID, in: dependencies.managedObjectContext) else { return }
            share.editorsCanShare = enabled
            try? dependencies.managedObjectContext.saveOrRollback()
        }
        updateSubject.send()
    }

    private func createShare() async throws -> DirectShareMetadata {
        guard let node else { throw ShareMetadataErrors.nodeIsMissing }
        _ = try await dependencies.shareCreator.createShare(for: node)
        return try await fetchShareMetaData(cleanUpLocalStateWhenNecessary: false)
    }
}

// MARK: - CoreData
extension ShareMetadataController {
    private func makeObserver() -> FetchedResultsControllerObserver<Node> {
        let controller = NSFetchedResultsController(
            fetchRequest: makeRequest(),
            managedObjectContext: dependencies.managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        return FetchedResultsControllerObserver(controller: controller)
    }

    private func makeRequest() -> NSFetchRequest<Node> {
        let fetchRequest = Node.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = makePredicate()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(Node.id), ascending: true)]
        return fetchRequest
    }

    private func makePredicate() -> NSPredicate {
        let idPredicate = NSPredicate(format: "%K == %@", #keyPath(Node.id), nodeIdentifier.nodeID)
        let volumePredicate = NSPredicate(format: "%K == %@", #keyPath(Node.volumeID), nodeIdentifier.volumeID)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [idPredicate, volumePredicate])
    }

    private func handleNodeUpdate(_ node: Node) {
        dependencies.managedObjectContext.performAndWait {
            self.isPublicLinkEnabled = node.isShared
            self.itemName = (try? node.decryptName()) ?? ""
            // Resolve the managed standard share the same way as `getDirectShare`, so member
            // listing/management (which relies on `shareID`) works for an admin operating on a node
            // reached through an ancestor share — not only for the owner of the item itself.
            self.shareID = node.getStandardShare()?.id
            self.editorsCanShare = node.getStandardShare()?.editorsCanShare ?? false
        }
        updateSubject.send()
    }

    private func mapping(coreDataShare: CoreDataShare, linkID: String) throws -> DirectShareMetadata {
        guard
            let flags = coreDataShare.flags,
            let creator = coreDataShare.creator,
            let shareKey = coreDataShare.key,
            let passphrase = coreDataShare.passphrase,
            let passphraseSignature = coreDataShare.passphraseSignature,
            let type = PDClient.Share.´Type´(rawValue: Int(coreDataShare.type.rawValue))
        else {
            throw ShareMetadataErrors.needToFetchShareMetadata
        }

        // The address to sign invitations with is the current user's own address on the node's
        // context share, not an address derived from `coreDataShare`: a share created by an admin via
        // node-key access lists no membership for them, so `coreDataShare.getAddressID()` would fail.
        guard let contextShareAddressID = node?.contextShareSignerAddressID(ownedBy: dependencies.sessionVault.addressIDs) else {
            throw ShareMetadataErrors.missingContextShareAddress
        }
        let share = PDClient.Share(
            flags: flags,
            shareID: coreDataShare.id,
            volumeID: coreDataShare.volumeID,
            linkID: linkID,
            creator: creator,
            addressID: coreDataShare.addressID,
            key: shareKey,
            passphrase: passphrase,
            passphraseSignature: passphraseSignature,
            type: type
        )
        guard let rootNodeKey = coreDataShare.root?.nodeKey, let passphrase = try? coreDataShare.root?.decryptPassphrase() else {
            throw ShareMetadataErrors.missingRootNodeKey
        }
        let nodeKey = DecryptionKey(privateKey: rootNodeKey, passphrase: passphrase)
        return DirectShareMetadata(
            share: share,
            rootNodeKey: nodeKey,
            contextShareAddressID: contextShareAddressID
        )
    }

    func fetchShareMetaData() async throws -> DirectShareMetadata {
        try await fetchShareMetaData(cleanUpLocalStateWhenNecessary: true)
    }

    /// Bootstraps the node's standard share from the backend.
    ///
    /// - Parameter cleanUpLocalStateWhenNecessary: when the backend reports the share no longer exists
    ///   (2501 — e.g. the item was unshared on another client while a stale copy lingered locally),
    ///   purge the dead local share and throw `.shareRemovedRemotely` so the caller can start sharing
    ///   from scratch. Disabled while bootstrapping a share we just created, to avoid a purge/recreate
    ///   loop.
    private func fetchShareMetaData(cleanUpLocalStateWhenNecessary: Bool) async throws -> DirectShareMetadata {
        guard let shareID else { throw ShareMetadataErrors.shareIDIsMissing }
        do {
            let fetchedShare = try await dependencies.remoteShareDataSource.getMetadata(forShare: shareID)
            let metadata = try await dependencies.managedObjectContext.perform {
                let share = self.dependencies.storage.updateShare(fetchedShare, in: self.dependencies.managedObjectContext)
                try self.dependencies.managedObjectContext.saveOrRollback()
                self.editorsCanShare = share.editorsCanShare
                return try self.mapping(coreDataShare: share, linkID: fetchedShare.linkID)
            }
            updateSubject.send()
            return metadata
        } catch let error where cleanUpLocalStateWhenNecessary
            && error.bestShotAtReasonableErrorCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue {
            try await removeStandardShare()
            throw ShareMetadataErrors.shareRemovedRemotely
        }
    }

    /// Removes the node's stale standard share (and its share URLs / memberships) from the local DB
    /// after the backend confirmed it no longer exists, so the node is no longer treated as shared.
    private func removeStandardShare() async throws {
        guard let node else { throw ShareMetadataErrors.nodeIsMissing }
        try await dependencies.managedObjectContext.perform {
            let moc = self.dependencies.managedObjectContext
            guard let staleShare = node.getStandardShare() else { return }
            staleShare.shareUrls.forEach(moc.delete)
            staleShare.members.forEach(moc.delete)
            node.removeFromDirectShares(staleShare)
            moc.delete(staleShare)
            node.isShared = false
            try moc.saveOrRollback()
        }
        updateSubject.send()
    }
}

extension ShareMetadataController {
    enum ShareMetadataErrors: Error {
        case nodeIsMissing
        case shareIDIsMissing
        case needToFetchShareMetadata
        case createShareFailed
        case directShareIsMissing
        case missingRootNodeKey
        case missingContextShareAddress
        case shareRemovedRemotely
    }

    struct Dependencies {
        let managedObjectContext: NSManagedObjectContext
        let remoteShareDataSource: RemoteShareMetadataDataSource
        let shareCreator: ShareCreatorProtocol
        let storage: StorageManager
        let sessionVault: SessionVault
    }
}
