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
import PDClient

public extension Tower {
    var didFetchAllTrash: Bool {
        get { storage.finishedFetchingTrash ?? false }
        set { storage.finishedFetchingTrash = newValue }
    }
    
    func getTrash(shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<[Node], Error>) -> Void) {
        cloudSlot?.scanTrashed(shareID: shareID, page: page, pageSize: size, handler: handler)
    }

    @available(*, deprecated, message: "Use the NodeIdentifier version")
    func delete(nodes: [String], shareID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let groups = nodes.splitInGroups(of: 150)

        groups.forEach { linkGroup in
            cloudSlot?.delete(shareID: shareID, linkIDs: linkGroup) { [unowned self] result in
                completion(result.map { self.setToBeDeleted(linkGroup) })
            }
        }
    }

    /*
     This method deals with deleting automatically files whose upload process ha not been finished successfully
     and cannot be resumed; and deleting manually when the user cancels the upload.
     It's purpose is to free the memory from the user's quota sooner.
     As currently we don't support multiple operations for non-finished file uploads it has no sense making it
     able to handle more than 150 items at the same time.
     */
    func deleteNodesInFolder(nodes: [String], folder: String, shareID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        cloudSlot?.deleteNodeInFolder(shareID: shareID, folderID: folder, nodeIDs: nodes, completion: { [unowned self] result in
            completion(result.map { self.setToBeDeleted(nodes) })
        })
    }

    @available(*, deprecated, message: "Use the NodeIdentifier version")
    func emptyTrash(nodes: [String], shareID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        cloudSlot?.emptyTrash(shareID: shareID) { [unowned self] result in
            completion(result.map { self.setToBeDeleted(nodes) })
        }
    }

    @available(*, deprecated, message: "Use the NodeIdentifier version")
    func restoreFromTrash(shareID: String, nodes: [String], completion: @escaping (Result<Void, Error>) -> Void)  {
        let groups = nodes.splitInGroups(of: 150)

        groups.forEach { linkGroup in
            cloudSlot?.restore(shareID: shareID, linkIDs: linkGroup) { [unowned self] result in
                completion( result.flatMap { completeRestoration(original: linkGroup, failed: $0, action: self.restoreLocally) })
            }
        }
    }

    private func completeRestoration(original: [String], failed: [PartialFailure], action performActionWith: ([String]) -> Void) -> Result<Void, Error> {
        let failedIDs = Set(failed.map(\.id))
        let successful = original.filter { !failedIDs.contains($0) }
        performActionWith(successful)
        return failed.isEmpty ? .success : .failure(failed[0].error)
    }

    private func trashNodeLocally(_ ids: [String]) {
        let moc = storage.backgroundContext
        moc.performAndWait {
            let newNodes = storage.fetchNodes(ids: ids, moc: moc)
            newNodes.forEach { $0.state = .deleted }
            try? moc.saveWithParentLinkCheck()
        }
    }

    /// ⚠️ A local node only exists in the user's device. There is no point to mark the Node as trash because this state should not be representable. Delete directly.
    func trashLocalNode(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        Log.info("Will delete local node", domain: .storage)
        let moc = storage.backgroundContext
        moc.performAndWait {
            do {
                let newNodes = storage.fetchNodes(ids: ids, moc: moc)
                newNodes.forEach { $0.state = .deleted }
                try moc.saveWithParentLinkCheck()
            } catch {
                Log.error(error.localizedDescription, domain: .storage)
            }
        }
    }

    private func setToBeDeleted(_ ids: [String]) {
        // should happen on a main context because changes a transient property relevant to main context only
        // moc.saveWithSpecialCheck() is not needed by same reason
        let moc = storage.mainContext
        let nodes = storage.fetchNodes(ids: ids, moc: moc)
        moc.performAndWait {
            nodes.forEach {
                $0.setToBeDeletedRecursivelly()
            }
        }
    }

    private func restoreLocally(_ ids: [String]) {
        let moc = storage.backgroundContext
        let nodes = storage.fetchNodes(ids: ids, moc: moc)
        moc.performAndWait {
            nodes.forEach { $0.state = .active }
            try? moc.saveWithParentLinkCheck()
        }
    }
}

// MARK: - New APIs with NodeIdentifier
public extension Tower {
    func trash(_ nodes: [TrashingNodeIdentifier], completion: @escaping (Result<Void, Error>) -> Void) {
        Task { [weak self] in
            var requestError: Error?

            do {
                for group in nodes.splitIntoChunks() {
                    guard let self = self else { return }

                    try await self.trash(shareID: group.share, parentID: group.parent, linkIDs: group.links)
                }
            } catch {
                requestError = error
            }

            if let requestError = requestError {
                completion(.failure(requestError))
            } else {
                completion(.success)
            }
        }
    }

    func trash(shareID: String, parentID: String, linkIDs: [String]) async throws {
        try await cloudSlot.trash(shareID: shareID, parentID: parentID, linkIDs: linkIDs)
        self.trashNodeLocally(linkIDs)
    }

    func delete(_ nodes: [NodeIdentifier], completion: @escaping (Result<Void, Error>) -> Void) {
        Task { [weak self] in
            var requestError: (any Error)?
            var links = [String]()
            
            do {
                for group in nodes.splitIntoChunks() {
                    guard let cloudSlot = self?.cloudSlot else { break } // emptyTrash is async, Tower may be deallocated meanwhile
                    
                    try await cloudSlot.delete(shareID: group.share, linkIDs: group.links)
                    links.append(contentsOf: group.links)
                }
            } catch {
                requestError = error
            }
            
            self?.setToBeDeleted(links)

            if let requestError = requestError {
                completion(.failure(requestError))
            } else {
                completion(.success)
            }
        }
    }

    func emptyTrash(_ nodes: [NodeIdentifier], completion: @escaping (Result<Void, Error>) -> Void) {
        Task { [weak self] in
            var requestError: (any Error)?
            var links = [String]()
            
            do {
                for group in nodes.splitIntoChunks() {
                    guard let cloudSlot = self?.cloudSlot else { break } // emptyTrash is async, Tower may be deallocated meanwhile
                    
                    try await cloudSlot.emptyTrash(shareID: group.share)
                    links.append(contentsOf: group.links)
                }
            } catch {
                requestError = error
            }
        
            self?.setToBeDeleted(links)
            
            if let requestError = requestError {
                completion(.failure(requestError))
            } else {
                completion(.success)
            }
        }
    }

    func restore(_ nodes: [NodeIdentifier], completion: @escaping (Result<Void, Error>) -> Void)  {
        Task { [weak self] in
            var requestError: (any Error)?
            var failed = [PartialFailure]()
            var links = Set<String>()

            do {
                for group in nodes.splitIntoChunks() {
                    guard let cloudSlot = self?.cloudSlot else { break } // restoration is async, Tower may be deallocated meanwhile
                    
                    let groupResult = try await cloudSlot.restore(shareID: group.share, linkIDs: group.links)
                    failed.append(contentsOf: groupResult)
                    links.formUnion(group.links)
                }
            } catch {
                requestError = error
            }
                
            let successfulIDs = links.subtracting(failed.map(\.id))
            self?.restoreLocally(successfulIDs)
            
            if let atLeastOneError = requestError ?? failed.first?.error {
                completion(.failure(atLeastOneError))
            } else {
                completion(.success)
            }
        }
    }
}

private extension Tower {
    func restoreLocally(_ ids: Set<String>) {
        self.restoreLocally(Array(ids))
    }
}

public struct TrashingNodeIdentifier: Equatable, Hashable {
    public let shareID: String
    public let parentID: String
    public let nodeID: String

    public init(nodeID: String, shareID: String, parentID: String) {
        self.nodeID = nodeID
        self.shareID = shareID
        self.parentID = parentID
    }
}

public extension Node {
    var isLocalFile: Bool {
        if self is Folder {
            return false
        }

        guard let file = self as? File,
              UUID(uuidString: file.id) != nil,
              let revisionDraft = file.activeRevisionDraft,
              revisionDraft.uploadState == .created, revisionDraft.uploadState == .encrypted  else {
            return false
        }
        return true
    }
}
