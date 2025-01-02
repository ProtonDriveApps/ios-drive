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

public protocol PublicLinkDeleter {
    func deletePublicLink(_ identifier: PublicLinkIdentifier) async throws
}

public final class RemoteCachingPublicLinkDeleter: PublicLinkDeleter {

    private let client: Client
    private let storage: StorageManager
    private let shareDeleter: ShareDeleter

    public init(client: Client, storage: StorageManager, shareDeleter: ShareDeleter) {
        self.client = client
        self.storage = storage
        self.shareDeleter = shareDeleter
    }

    public func deletePublicLink(_ identifier: PublicLinkIdentifier) async throws {
        try await deleteShareURL(identifier.id, identifier.shareID)
        // If the share still has member, invitation...etc, soft deletion will fail
        try? await shareDeleter.deleteShare(identifier.shareID, force: false)
    }

    private func deleteShareURL(_ id: String, _ shareID: String) async throws {
        try await self.client.deleteShareURL(id: id, shareID: shareID)

        let context = storage.backgroundContext
        try await context.perform {
            guard let shareURL = ShareURL.fetch(id: id, in: context) else { return }
            shareURL.share.root?.isShared = false
            context.delete(shareURL)
            try context.saveOrRollback()
        }
    }    
}
