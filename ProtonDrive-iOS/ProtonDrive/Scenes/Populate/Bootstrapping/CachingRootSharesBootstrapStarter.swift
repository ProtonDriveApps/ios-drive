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
import PDCore
import PDClient
import CoreData

final class CachingRootSharesBootstrapStarter: AppBootstrapper {
    typealias Share = ListSharesEndpoint.Response.Share

    private let storage: StorageManager
    private let context: NSManagedObjectContext
    private let listShares: () async throws -> [ListSharesEndpoint.Response.Share]
    private let bootstrapRoot: (_ nodeID: String, _ shareID: String) async throws -> Root

    init(
        listShares: @escaping () async throws -> [ListSharesEndpoint.Response.Share],
        bootstrapRoot: @escaping (_ nodeID: String, _ shareID: String) async throws -> Root,
        storage: StorageManager
    ) {
        self.storage = storage
        self.context = storage.backgroundContext
        self.listShares = listShares
        self.bootstrapRoot = bootstrapRoot
    }

    func bootstrap() async throws {
        let remoteRootShares = try await fetchRemoteRootShares()
        let (mainShare, otherRootShares) = try validate(remoteRootShares)
        try await bootstrap(mainShare, otherRootShares)
    }

    private func fetchRemoteRootShares() async throws -> [Share] {
        try await listShares()
            .filter { $0.state == .active }
            .filter { $0.type != .standard }
            .filter { $0.type != .device }
    }

    private func validate(_ shares: [Share]) throws -> (mainShare: Share, otherRootShares: [Share]) {
        let mainShares = shares.filter({ $0.type == .main })
        let otherRootShares = shares.filter({ $0.type != .main })

        guard mainShares.count == 1 else {
            throw DriveError("There are multiple main shares in the remote")
        }
        let mainShare = mainShares[0]
        return (mainShare, otherRootShares)
    }

    private func bootstrap(_ mainShare: Share, _ otherRootShares: [Share]) async throws {
        var roots: [Root] = []

        try await withThrowingTaskGroup(of: Root.self) { group in
            // Add the main share bootstrap task to the group
            group.addTask {
                return try await self.bootstrapRoot(mainShare.shareID, mainShare.linkID)
            }

            // Add the other root shares bootstrap tasks to the group
            for share in otherRootShares {
                group.addTask {
                    return try await self.bootstrapRoot(share.shareID, share.linkID)
                }
            }

            // Collect all the bootstrapped shares
            for try await root in group {
                roots.append(root)
            }
        }

        // Caching the bootstrapped shares
        try await self.cache(roots)
    }

    private func cache(_ roots: [Root]) async throws {
        try await context.perform {
            for root in roots {
                self.storage.updateShare(root.share, in: self.context)
                self.storage.updateLink(root.link, in: self.context)
            }
            try self.context.saveOrRollback()
        }
    }
}
