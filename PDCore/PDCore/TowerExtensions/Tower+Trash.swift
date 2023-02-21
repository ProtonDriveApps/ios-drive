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
    
    func getTrash(shareID: String, page: Int, pageSize size: Int, handler: @escaping (Result<Int, Error>) -> Void) {
        cloudSlot?.scanTrashed(shareID: shareID, page: page, pageSize: size, handler: handler)
    }

    func trash(nodes: [Node], completion: @escaping (Result<Void, Error>) -> Void)  {
        guard let parent = nodes.first?.parentLink else { return }
        let groups = nodes.map(\.id).splitInGroups(of: 150)

        groups.forEach { linkGroup in
            cloudSlot?.trash(shareID: parent.shareID, parentLinkID: parent.id, linkIDs: linkGroup) { [unowned self] result in
                completion(result.map { self.trashNodeLocally(nodes) })
            }
        }
    }

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

    func emptyTrash(nodes: [String], shareID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        cloudSlot?.emptyTrash(shareID: shareID) { [unowned self] result in
            completion(result.map { self.setToBeDeleted(nodes) })
        }
    }

    func restoreFromTrash(shareID: String, nodes: [String], completion: @escaping (Result<Void, Error>) -> Void)  {
        let groups = nodes.splitInGroups(of: 150)

        groups.forEach { linkGroup in
            cloudSlot?.restore(shareID: shareID, linkIDs: linkGroup) { [unowned self] result in
                completion( result.flatMap { complete(original: linkGroup, failed: $0, action: self.restoreLocally) })
            }
        }
    }

    private func complete(original: [String], failed: [PartialFailure], action performActionWith: ([String]) -> Void) -> Result<Void, Error> {
        let failedIDs = Set(failed.map(\.id))
        let successful = original.filter { !failedIDs.contains($0) }
        performActionWith(successful)
        return failed.isEmpty ? .success : .failure(failed[0].error)
    }

    // This parameter `Node` comes from a main context, to be replaced by id parameter
    private func trashNodeLocally(_ nodes: [Node]) {
        let moc = storage.mainContext
        moc.performAndWait {
            let newNodes = storage.fetchNodes(ids: nodes.map(\.id), moc: moc)
            newNodes.forEach { $0.state = .deleted }
            try? moc.save()
        }
    }

    private func setToBeDeleted(_ ids: [String]) {
        // should happen on a main context because changes a transient property relevant to main context only
        // moc.save() is not needed by same reason
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
            try? moc.save()
        }
    }
}
