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

import CoreData

public protocol MovedNodesUpdateRepositoryProtocol {
    func updateLocalDB(newParent: Folder, nodes: [Node], infos: [MultipleMovingNode.LinkInfo]) async throws
}

// Update the local database for nodes that have been moved
// This avoids waiting for events and improves UX
public final class MovedNodesUpdateRepository: MovedNodesUpdateRepositoryProtocol {
    private let moc: NSManagedObjectContext

    public init(moc: NSManagedObjectContext) {
        self.moc = moc
    }

    public func updateLocalDB(newParent: Folder, nodes: [Node], infos: [MultipleMovingNode.LinkInfo]) async throws {
        try await moc.perform {
            let newParent = newParent.in(moc: self.moc)
            for node in nodes {
                let node = node.in(moc: self.moc)
                guard let info = infos.first(where: { $0.link.LinkID == node.id }) else { continue }
                let link = info.link

                node.name = link.Name
                node.nodeHash = link.Hash
                node.nodePassphrase = link.NodePassphrase
                if info.isAnonymous {
                    if let signature = link.NodePassphraseSignature {
                        node.nodePassphraseSignature = signature
                    }
                    node.nameSignatureEmail = info.signatureEmail
                    node.signatureEmail = info.signatureEmail
                }

                node.parentFolder = newParent
                if let photo = node as? Photo {
                    photo.albums.removeAll()
                }
            }

            try self.moc.saveOrRollback()
        }
    }
}
