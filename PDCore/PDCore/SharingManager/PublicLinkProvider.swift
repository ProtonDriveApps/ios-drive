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

public protocol PublicLinkProvider {
    func getPublicLink(
        for node: NodeIdentifier,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier
}

public final class RemoteCachingPublicLinkProvider: PublicLinkProvider {

    private let client: Client
    private let storage: StorageManager
    private let shareCreator: ShareCreatorProtocol
    private let publicLinkCreator: PublicLinkCreator

    enum State {
        case notShared(node: Node)
        case started(shareID: String)
        case shared(shareID: String, shareURLID: String)
    }

    public init(client: Client, storage: StorageManager, shareCreator: ShareCreatorProtocol, publicLinkCreator: PublicLinkCreator) {
        self.client = client
        self.storage = storage
        self.shareCreator = shareCreator
        self.publicLinkCreator = publicLinkCreator
    }

    /// Retrieve the identifier and create a secure link if one does not already exist.
    public func getPublicLink(
        for node: NodeIdentifier,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier {
        Log.info("\(type(of: self)) open secure link for \(node)", domain: .sharing)

        let state = try await getState(for: node)

        switch state {
        case .notShared(let node):
            return try await createShareAndShareURL(for: node, permissions: permissions)
        case .started(let shareID):
            return try await scanShareAndCreateShareURL(shareID: shareID, permissions: permissions)
        case .shared(let shareID, let shareURLID):
            return try await scanShareAndShareURL(shareID: shareID, shareURLID: shareURLID)
        }
    }

    private func scanShareAndShareURL(shareID: String, shareURLID: String) async throws -> PublicLinkIdentifier {
        let shareResponse = try await client.bootstrapShare(id: shareID)
        let shareURLResponses = try await client.getShareUrl(shareID: shareID)

        guard let shareURLResponse = shareURLResponses.first else {
            throw DriveError("There should be one ShareURL per Share")
        }

        let context = storage.backgroundContext

        return try await context.perform {
            self.storage.updateShare(shareResponse, in: context)
            let shareURL = self.storage.updateShareURL(shareURLResponse, in: context)
            try context.saveOrRollback()
            return shareURL.identifier
        }
    }

    private func scanShareAndCreateShareURL(
        shareID: String,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier {
        let context = storage.backgroundContext

        let shareResponse = try await client.bootstrapShare(id: shareID)
        try await context.perform {
            self.storage.updateShare(shareResponse, in: context)
            try context.saveOrRollback()
        }

        return try await publicLinkCreator.createPublicLink(
            share: ShareIdentifier(id: shareID),
            permissions: permissions
        )
    }

    private func createShareAndShareURL(
        for node: Node,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier {
        let context = storage.backgroundContext
        let share = try await shareCreator.createShare(for: node)
        let shareIdentifier = await context.perform { share.in(moc: context).identifier }
        return try await publicLinkCreator.createPublicLink(share: shareIdentifier, permissions: permissions)
    }

    private func getState(for node: NodeIdentifier) async throws -> State {
        let context = storage.backgroundContext
        return try await context.perform {
            guard let node = Node.fetch(identifier: node, allowSubclasses: true, in: context) else {
                throw DriveError("Could not find node with identifier \(node)")
            }

            if let directShare = node.directShares.first {
                if let shareURL = directShare.shareUrls.first {
                    return .shared(shareID: directShare.id, shareURLID: shareURL.id)
                } else {
                    return .started(shareID: directShare.id)
                }
            } else {
                return .notShared(node: node)
            }
        }
    }
}
