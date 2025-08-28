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
import PDCore
import PDCoreIOS

protocol SharedWithMeAlbumStarterProtocol {
    func bootstrap(remoteLinks: [SharedWithMeLink]) async throws
}

/// Remove non-existent album listing and volume.
/// Ask EventManager to monitor related volume events.
final class SharedWithMeAlbumStarter: SharedWithMeAlbumStarterProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func bootstrap(remoteLinks: [SharedWithMeLink]) async throws {
        // Clean up local links
        let volumes = try await refreshLocalItems(links: remoteLinks)

        // Adjust events
        await setupEvents(removedVolumeIds: volumes.removedVolumeIds, addedVolumeIds: volumes.addedVolumeIds)
    }

    @MainActor
    private func setupEvents(removedVolumeIds: [VolumeID], addedVolumeIds: [VolumeID]) async {
        dependencies.sharedVolumesEventsController.removeVolumeIds(removedVolumeIds)
        dependencies.sharedVolumesEventsController.appendVolumeIds(addedVolumeIds)
    }
}

// MARK: - Clean up local db
extension SharedWithMeAlbumStarter {
    private func refreshLocalItems(links: [SharedWithMeLink]) async throws -> (removedVolumeIds: [VolumeID], addedVolumeIds: [VolumeID]) {
        var addedVolumeIds = [VolumeID]()
        var removedVolumeIds = [VolumeID]()

        try await dependencies.context.perform {
            let localItems = try self.fetchLocalItems()

            let remoteShareIds = Set(links.map(\.shareId))
            let localShareIds = Set(localItems.map(\.shareID))

            // Delete local items that are no longer in remote
            let deletedLinks = localItems.filter { listing in
                guard let shareID = listing.shareID else { return true }
                return !remoteShareIds.contains(shareID)
            }
            self.deleteLocalItems(deletedLinks)

            // Clean up orphaned volumes
            removedVolumeIds = self.deleteEmptyVolumes()

            // Find volumes not yet in local db
            addedVolumeIds = links
                .filter { !localShareIds.contains($0.shareId) }
                .map(\.volumeId)
        }

        return (removedVolumeIds, addedVolumeIds)
    }

    private func fetchLocalItems() throws -> [CoreDataAlbumListing] {
        let factory = AlbumListObserverFactory(
            managedObjectContext: dependencies.context,
            storageManager: dependencies.storage,
            streamConfiguration: dependencies.streamConfiguration
        )
        let controller = try factory.makeController(filter: .sharedWithMe)
        try controller.performFetch()
        return controller.managedObjectContext.performAndWait {
            return controller.fetchedObjects ?? []
        }
    }

    private func deleteLocalItems(_ items: [CoreDataAlbumListing]) {
        do {
            for item in items {
                if let shares = item.album?.directShares {
                    shares.forEach { dependencies.context.delete($0) }
                }
                if let album = item.album {
                    dependencies.context.delete(album)
                }
                dependencies.context.delete(item)
            }

            // Save the context after deleting objects
            try dependencies.context.saveOrRollback()
        } catch {
            Log.error("Error deleting shares", error: error, domain: .albums)
        }
    }

    private func deleteEmptyVolumes() -> [VolumeID] {
        do {
            let volumes = try dependencies.storage.fetchOrphanedVolumes(in: dependencies.context)
            volumes.forEach { dependencies.context.delete($0) }

            // Save the context again after deleting volumes
            try dependencies.context.saveOrRollback()
            return volumes.map(\.id)
        } catch {
            Log.error("Error deleting orphaned volumes", error: error, domain: .storage)
            return []
        }
    }
}

extension SharedWithMeAlbumStarter {
    struct Dependencies {
        let context: NSManagedObjectContext
        let storage: StorageManager
        let sharedVolumesEventsController: SharedVolumesEventsControllerProtocol
        let streamConfiguration: PhotoStreamConfiguration
    }
}
