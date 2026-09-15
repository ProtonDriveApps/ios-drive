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
import PDCoreIOS
import PDCore
import PDClient
import CoreData

final class RemoteSharesBootstrapStarter: AppBootstrapper {
    typealias Share = ListSharesEndpoint.Response.Share

    private let storage: StorageManager
    private let context: NSManagedObjectContext
    private let listShares: () async throws -> [ListSharesEndpoint.Response.Share]
    private let bootstrapRoot: (_ nodeID: String, _ shareID: String) async throws -> Root
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let connectionStateResource: ConnectionStateResource
    private let volumeLockShareStrategy: VolumeLockShareStrategy
    private weak var volumeLockController: VolumeLockController?

    init(
        listShares: @escaping () async throws -> [ListSharesEndpoint.Response.Share],
        bootstrapRoot: @escaping (_ nodeID: String, _ shareID: String) async throws -> Root,
        featureFlagsController: FeatureFlagsControllerProtocol,
        storage: StorageManager,
        connectionStateResource: ConnectionStateResource,
        volumeLockController: VolumeLockController? = nil,
        volumeLockShareStrategy: VolumeLockShareStrategy = DefaultVolumeLockShareStrategy()
    ) {
        self.storage = storage
        self.context = storage.backgroundContext
        self.listShares = listShares
        self.featureFlagsController = featureFlagsController
        self.bootstrapRoot = bootstrapRoot
        self.connectionStateResource = connectionStateResource
        self.volumeLockController = volumeLockController
        self.volumeLockShareStrategy = volumeLockShareStrategy
    }

    func bootstrap() async throws {
        let remoteRootShares = try await fetchRemoteRootShares()
        let (mainShare, otherRootShares, lockedShares) = try validate(remoteRootShares)
        var messages = [
            "Main volume: \(mainShare.volumeID), share: \(mainShare.shareID)",
        ]
        for share in otherRootShares {
            messages.append("Other volume: \(share.volumeID), share: \(share.shareID), type: \(share.volumeType)")
        }
        for share in lockedShares {
            messages.append("Locked volume: \(share.volumeID), share: \(share.shareID), type: \(share.volumeType)")
        }
        Log.info(messages.joined(separator: "\n"), domain: .applicationBootstrap)

        try await bootstrap(mainShare, otherRootShares)
        await volumeLockController?.applyShareBootstrapResult(lockedShares: lockedShares)
    }

    private func fetchRemoteRootShares() async throws -> [Share] {
        guard connectionStateResource.currentState.isReachable else {
            if try await hasCache() { return [] }
            throw NetworkStateError.deviceIsOffline
        }
        return try await listShares()
            .filter { $0.state == .active || $0.state == .locked }
            .filter { $0.type != .standard }
    }

    private func validate(_ shares: [Share]) throws -> (mainShare: Share, otherRootShares: [Share], lockedShares: [Share]) {
        let mainShares = shares.filter({ $0.type == .main && $0.locked == false })
        let otherRootShares = shares.filter({ $0.type != .main && $0.locked == false })
        let lockedShares = volumeLockShareStrategy.lockedShares(in: shares)

        if mainShares.isEmpty { throw DriveError("There is no active and unlocked main share") }
        guard mainShares.count == 1 else {
            throw DriveError("There are multiple main shares in the remote")
        }
        let mainShare = mainShares[0]
        return (mainShare, otherRootShares, lockedShares)
    }

    private func bootstrap(
        _ mainShare: Share,
        _ otherRootShares: [Share]
    ) async throws {
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
        try await self.cache(roots, shares: [mainShare] + otherRootShares)
    }

    private func cache(_ roots: [Root], shares: [Share]) async throws {
        try await context.perform { [context] in
            for root in roots {
                guard let share = shares.first(where: { $0.shareID == root.share.shareID }) else { continue }
                self.storage.updateShare(root.share, in: context)
                let volume = Volume.fetchOrCreate(id: share.volumeID, in: context)
                volume.type = share.volumeType == .regular ? .main : .photo
                self.storage.updateLink(root.link, using: context)
            }
            try self.context.saveOrRollback()
        }
    }

    private func hasCache() async throws -> Bool {
        try await context.perform { [context] in
            let shares = try self.storage.fetchShares(moc: context)
            return shares.isEmpty == false
        }
    }
}
