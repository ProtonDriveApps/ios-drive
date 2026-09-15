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

final class LocalRootSharesBootstrapStarter: AppBootstrapper {
    private let storage: StorageManager
    private let context: NSManagedObjectContext
    private let connectionStateResource: ConnectionStateResource

    init(storage: StorageManager, connectionStateResource: ConnectionStateResource) {
        self.storage = storage
        self.context = storage.backgroundContext
        self.connectionStateResource = connectionStateResource
    }

    func bootstrap() async throws {
        try await context.perform {
            let shares = self.storage.getMainShares(in: self.context)

            if shares.isEmpty {
                // If we do not have any share it's the case of a new session after login -> fallback
                try self.throwError("Empty database, fetch new data")
            } else {
                // May be non-migrated db or already migrated db, just non-empty
                try self.validate(shares)
            }

            let photoShares = self.storage.getShares(type: .photos, in: self.context)
            try self.validate(photoShares: photoShares)
        }
    }

    private func validate(photoShares: [Share]) throws {
        // and we'll advise to relogin
        guard !photoShares.isEmpty else {
            Log.info("There's no photo share yet", domain: .metadata)
            return
        }

        guard photoShares.count == 1 else {
            Log.error("Multiple photo shares found", error: nil, domain: .metadata)
            try throwError("Multiple photo shares found")
            return
        }

        let photoShare = photoShares[0]
        guard let addressID = photoShare.addressID, !addressID.isEmpty else {
            Log.error("Photo share is missing addressID", error: nil, domain: .metadata)
            try throwError("Photo share doesn't have nonempty addressID")
            return
        }
        Log.info("Photo volume: \(photoShare.volume?.id ?? "unknown"), share: \(photoShare.id)", domain: .applicationBootstrap)
    }

    private func validate(_ shares: [Share]) throws {
        // MARK: Checks that preserve integrity of the drive model
        let shares = shares
            .filter { $0.type == .main }
            .filter { $0.state == .active }

        guard shares.count < 2 else {
            try throwError("There are multiple main shares in the local DB")
            return
        }

        guard let mainShare = shares.first else {
            try throwError("There is no main share in the local DB")
            return
        }

        guard let root = mainShare.root else {
            try throwError("Main share has no root")
            return
        }

        guard let volume = mainShare.volume, !volume.id.isEmpty else {
            try throwError("Main share has no volume downloaded")
            return
        }

        // MARK: Migration checks
        if root.volumeID.isEmpty || mainShare.volumeID.isEmpty {
            try migrateNodesAndShares(volume: volume)
        }

        if mainShare.members.isEmpty {
            try throwError("Main share has no members")
        } else {
            Log.info("Drive has local data available.", domain: .application)
            Log.info("Main volume: \(volume.id), share: \(mainShare.id)", domain: .applicationBootstrap)
        }
    }

    private func migrateNodesAndShares(volume: Volume) throws {
        Log.error("Will start Share DB migration ✅.", error: nil, domain: .application)
        let migrator = VolumeBasedDatabaseMigrator(context: context)
        do {
            try migrator.migrateVolumelessRevisions(volumeID: volume.id)
            try migrator.migrateVolumelessBlocks(volumeID: volume.id)
            try migrator.migrateVolumelessThumbnails(volumeID: volume.id)
            try migrator.migrateVolumelessNodes(volumeID: volume.id)
            try migrator.migrateVolumelessShares(volumeID: volume.id)
            Log.error("Did end Share DB migration ✅.", error: nil, domain: .application)
        } catch {
            try throwError(error.localizedDescription)
        }
    }

    private func throwError(_ message: String) throws {
        if connectionStateResource.currentState.isReachable {
            throw NukingCacheError(message)
        } else {
            // When device is offline nuking cache make infinite stuck
            throw LoggingOutError(message)
        }
    }
}

final class VolumeBasedDatabaseMigrator {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func migrateVolumelessNodes(volumeID: String) throws {
        try migrateVolumelessEntity(entityName: "Node", volumeID: volumeID)
    }

    func migrateVolumelessShares(volumeID: String) throws {
        try migrateVolumelessEntity(entityName: "Share", volumeID: volumeID)
    }

    func migrateVolumelessRevisions(volumeID: String) throws {
        try migrateVolumelessEntity(entityName: "Revision", volumeID: volumeID)
    }

    func migrateVolumelessThumbnails(volumeID: String) throws {
        try migrateVolumelessEntity(entityName: "Thumbnail", volumeID: volumeID)
    }

    func migrateVolumelessBlocks(volumeID: String) throws {
        try migrateVolumelessEntity(entityName: "Block", volumeID: volumeID)
    }

    // Generalized function to handle the migration of different entities
    private func migrateVolumelessEntity(entityName: String, volumeID: String) throws {
        // Create a batch update request for the entity
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)

        // Set the predicate to find objects where VolumeID is empty
        batchUpdateRequest.predicate = NSPredicate(format: "volumeID == %@", "")

        // Set the properties to update
        batchUpdateRequest.propertiesToUpdate = ["volumeID": volumeID]

        // Specify that the request should update the objects and not just return information
        batchUpdateRequest.resultType = .updatedObjectsCountResultType

        // Execute the batch update request
        do {
            let batchUpdateResult = try context.execute(batchUpdateRequest) as? NSBatchUpdateResult
            if let updatedCount = batchUpdateResult?.result as? Int {
                Log.info("\(updatedCount) \(entityName)(s) updated.", domain: .storage)
            }
        } catch {
            throw NukingCacheError("Failed to update \(entityName)s: \(error)")
        }
    }
}
