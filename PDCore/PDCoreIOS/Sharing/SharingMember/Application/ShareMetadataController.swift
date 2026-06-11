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

protocol ShareMetadataProvider {
    var isPublicLinkEnabled: Bool { get }
    var itemName: String { get }
    var nodeIdentifier: NodeIdentifier { get }
    var shareID: String? { get }

    func getShareLink() throws -> SharedLink?
    func getDirectShare() async throws -> PDClient.Share
    func fetchShareMetaData() async throws -> PDClient.Share
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

    func getDirectShare() async throws -> PDClient.Share {
        guard let node else { throw ShareMetadataErrors.nodeIsMissing }
        do {
            let directShare: PDClient.Share? = try await dependencies.managedObjectContext.perform {
                if let share = node.directShares.first {
                    return try self.mapping(coreDataShare: share, linkID: node.id)
                }
                return nil
            }
            guard let directShare else { throw ShareMetadataErrors.directShareIsMissing }
            return directShare
        } catch ShareMetadataErrors.needToFetchShareMetadata {
            return try await fetchShareMetaData()
        } catch ShareMetadataErrors.directShareIsMissing {
            let directShare = try await createShare()
            return directShare
        } catch {
            throw error
        }
    }

    private func createShare() async throws -> PDClient.Share {
        guard let node else { throw ShareMetadataErrors.nodeIsMissing }
        _ = try await dependencies.shareCreator.createShare(for: node)
        return try await fetchShareMetaData()
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
            self.shareID = node.directShares.first?.id
        }
    }

    private func mapping(coreDataShare: CoreDataShare, linkID: String) throws -> PDClient.Share {
        guard
            let flags = coreDataShare.flags,
            let creator = coreDataShare.creator,
            let addressID = coreDataShare.addressID,
            let key = coreDataShare.key,
            let passphrase = coreDataShare.passphrase,
            let passphraseSignature = coreDataShare.passphraseSignature,
            let type = PDClient.Share.´Type´(rawValue: Int(coreDataShare.type.rawValue))
        else { throw ShareMetadataErrors.needToFetchShareMetadata }
        return .init(
            flags: flags,
            shareID: coreDataShare.id,
            volumeID: coreDataShare.volumeID,
            linkID: linkID,
            creator: creator,
            addressID: addressID,
            key: key,
            passphrase: passphrase,
            passphraseSignature: passphraseSignature,
            type: type
        )
    }

    private func mapping(metadata: ShareMetadata) -> PDClient.Share {
        return .init(
            flags: [],
            shareID: metadata.shareID,
            volumeID: metadata.volumeID,
            linkID: metadata.linkID,
            creator: metadata.creator,
            addressID: metadata.addressID,
            key: metadata.key,
            passphrase: metadata.passphrase,
            passphraseSignature: metadata.passphraseSignature,
            type: PDClient.Share.´Type´(rawValue: metadata.type) ?? .undefined
        )
    }

    func fetchShareMetaData() async throws -> PDClient.Share {
        guard let shareID else { throw ShareMetadataErrors.shareIDIsMissing }
        let fetchedShare = try await dependencies.remoteShareDataSource.getMetadata(forShare: shareID)
        try await dependencies.managedObjectContext.perform {
            self.dependencies.storage.updateShare(fetchedShare, in: self.dependencies.managedObjectContext)
            try self.dependencies.managedObjectContext.saveOrRollback()
        }
        return mapping(metadata: fetchedShare)
    }
}

extension ShareMetadataController {
    enum ShareMetadataErrors: Error {
        case nodeIsMissing
        case shareIDIsMissing
        case needToFetchShareMetadata
        case createShareFailed
        case directShareIsMissing
    }

    struct Dependencies {
        let managedObjectContext: NSManagedObjectContext
        let remoteShareDataSource: RemoteShareMetadataDataSource
        let shareCreator: ShareCreatorProtocol
        let storage: StorageManager
    }
}
