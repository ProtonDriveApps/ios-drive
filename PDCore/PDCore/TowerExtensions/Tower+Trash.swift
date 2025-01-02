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

    private func trashNodeLocally(_ ids: [String]) {
        let moc = storage.backgroundContext
        moc.performAndWait {
            let newNodes = storage.fetchNodes(ids: ids, moc: moc)
            newNodes.forEach { $0.state = .deleted }
            try? moc.saveOrRollback()
        }
    }

    /// ⚠️ A local node only exists in the user's device. There is no point to mark the Node as trash because this state should not be representable. Delete directly.
    func trashLocalNode(_ nodes: [TrashingNodeIdentifier]) throws {
        guard !nodes.isEmpty else { return }
        Log.info("Will delete local node", domain: .storage)
        
        let context = storage.backgroundContext

        try context.performAndWait {
            let newNodes = Node.fetch(identifiers: Set(nodes), allowSubclasses: true, in: context)
            newNodes.forEach { $0.state = .deleted }
            try context.saveOrRollback()
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
            try? moc.saveOrRollback()
        }
    }
}

// MARK: - New APIs with NodeIdentifier
public extension Tower {
    func trash(_ nodes: [TrashingNodeIdentifier]) async throws {
        try await cloudSlot.trash(nodes)
    }

    @available(iOS, deprecated, message: "Not used in iOS anymore, please use func trash(_ nodes: [TrashingNodeIdentifier]) async throws")
    func trash(shareID: String, parentID: String, linkIDs: [String]) async throws {
        try await cloudSlot.trash(shareID: shareID, parentID: parentID, linkIDs: linkIDs)
        self.trashNodeLocally(linkIDs)
    }

    func removeMember(shareID: String, memberID: String) async throws {
        try await cloudSlot.removeMember(shareID: shareID, memberID: memberID)
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
}

private extension Tower {
    func restoreLocally(_ ids: Set<String>) {
        self.restoreLocally(Array(ids))
    }
}

public struct TrashingNodeIdentifier: Equatable, Hashable, VolumeIdentifiable {
    public let volumeID: String
    public let shareID: String
    public let parentID: String
    public let nodeID: String

    public init(volumeID: String, shareID: String, parentID: String, nodeID: String) {
        self.volumeID = volumeID
        self.shareID = shareID
        self.parentID = parentID
        self.nodeID = nodeID
    }

    public var id: String { nodeID }
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
