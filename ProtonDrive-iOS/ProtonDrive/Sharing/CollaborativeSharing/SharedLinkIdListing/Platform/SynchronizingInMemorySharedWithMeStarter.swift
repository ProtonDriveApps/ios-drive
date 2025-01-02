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

import CoreData
import PDCore
import PDClient

public final class SynchronizingInMemorySharedWithMeStarter: SharedWithMeStarter, SharedLinkIdDataSource {
    private let client: Client
    private let storage: StorageManager
    private var allLinks: [ShareLink] = []
    private let context: NSManagedObjectContext
    private let sharedVolumesEventsController: SharedVolumesEventsControllerProtocol

    init(client: Client, storage: StorageManager, sharedVolumesEventsController: SharedVolumesEventsControllerProtocol) {
        self.client = client
        self.storage = storage
        self.context = storage.backgroundContext
        self.sharedVolumesEventsController = sharedVolumesEventsController
    }

    public func getLinks() -> [ShareLink] {
        return allLinks
    }

    public func bootstrap() async throws {
        // Fetch remote links
        allLinks = try await fetchAllLinks()

        // Clean up local links
        let volumes = await refreshLocalItems()

        // Adjust events
        await setupEvents(removedVolumeIds: volumes.removedVolumeIds, addedVolumeIds: volumes.addedVolumeIds)
    }

    private func refreshLocalItems() async -> (removedVolumeIds: [VolumeID], addedVolumeIds: [VolumeID]) {
        let localItems = storage.fetchCachedSharedWithMe(moc: context)
        var addedVolumeIds = [VolumeID]()
        var removedVolumeIds = [VolumeID]()

        await context.perform {
            let remoteShareIds = Set(self.allLinks.map(\.share))
            let localShareIds = Set(localItems.map { $0.share.id })

            // Delete local items that are no longer in remote
            let deletedLinks = localItems.filter { !remoteShareIds.contains($0.share.id) }
            self.deleteLocalItems(deletedLinks)

            // Clean up orphaned volumes
            removedVolumeIds = self.deleteEmptyVolumes()

            // Find volumes not yet in local db
            addedVolumeIds = self.allLinks
                .filter { !localShareIds.contains($0.share) }
                .map(\.volumeId)
        }

        return (removedVolumeIds, addedVolumeIds)
    }

    private func fetchAllLinks() async throws -> [ShareLink] {
        var fetchedLinks: [[ShareLink]] = []
        var lastPageId: String?
        var pageIndex = 0

        repeat {
            let response = try await client.getSharedWithMeLinks(lastPageId: lastPageId)
            let remoteLinks = response.links.map { ShareLink(link: $0.linkID, share: $0.shareID, volumeId: $0.volumeID) }

            fetchedLinks.append(remoteLinks)

            lastPageId = response.more ? response.anchorID : nil
            pageIndex += 1
        } while lastPageId != nil

        return fetchedLinks.flatMap { $0 }
    }

    // MARK: - Event loops

    @MainActor
    private func setupEvents(removedVolumeIds: [VolumeID], addedVolumeIds: [VolumeID]) async {
        sharedVolumesEventsController.removeVolumeIds(removedVolumeIds)
        sharedVolumesEventsController.appendVolumeIds(addedVolumeIds)
    }

    // MARK: - Cleaning up local DB

    private func deleteLocalItems(_ items: [(node: Node, share: PDCore.Share)]) {
        do {
            for item in items {
                context.delete(item.node)
                context.delete(item.share)
            }

            // Save the context after deleting objects
            try context.saveOrRollback()
        } catch {
            Log.error("Error deleting shares: \(error.localizedDescription)", domain: .storage)
        }
    }

    private func deleteEmptyVolumes() -> [VolumeID] {
        do {
            let volumes = try storage.fetchOrphanedVolumes(in: context)
            volumes.forEach {
                context.delete($0)
            }

            // Save the context again after deleting volumes
            try context.saveOrRollback()
            return volumes.map(\.id)
        } catch {
            Log.error("Error deleting orphaned volumes: \(error.localizedDescription)", domain: .storage)
            return []
        }
    }
}
