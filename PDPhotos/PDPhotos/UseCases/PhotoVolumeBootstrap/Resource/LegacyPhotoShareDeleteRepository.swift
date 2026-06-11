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

protocol LegacyPhotoShareDeleteRepositoryProtocol {
    func deleteLegacyPhotos() async throws
}

final class LegacyPhotoShareDeleteRepository: LegacyPhotoShareDeleteRepositoryProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func deleteLegacyPhotos() async throws {
        try await managedObjectContext.perform {
            // Get shares connected to own main volume
            let mainVolumeShares = try self.storageManager.fetchShares(moc: self.managedObjectContext)
                .filter { $0.volume?.type == .main }

            guard let legacyPhotoShare = mainVolumeShares.first(where: { $0.type == .photos && $0.volume?.type == .main }) else {
                Log.info("No legacy photo share found, skipping deleting", domain: .metadata)
                return
            }

            Log.info("Deleting legacy photos' standard shares.", domain: .metadata)
            try self.deleteStandardShares(mainVolumeShares: mainVolumeShares)

            Log.info("Deleting legacy photos listings.", domain: .metadata)
            try self.deletePhotosListings()

            Log.info("Deleting photos from legacy photos share", domain: .metadata)
            if let root = legacyPhotoShare.root as? Folder {
                try self.deletePhotosMetadata(root: root)

                Log.info("Deleting legacy photo share's root folder.", domain: .metadata)
                self.managedObjectContext.delete(root)
            }

            Log.info("Deleting legacy photo share.", domain: .metadata)
            self.managedObjectContext.delete(legacyPhotoShare)

            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func deleteStandardShares(mainVolumeShares: [CoreDataShare]) throws {
        mainVolumeShares.forEach { share in
            if share.type == .standard && (share.root is Photo) {
                self.managedObjectContext.delete(share)
            }
        }
        try self.managedObjectContext.saveOrRollback()
    }

    private func deletePhotosListings() throws {
        let fetchRequest = CoreDataPhotoListing.fetchRequest()
        let listings = try managedObjectContext.fetch(fetchRequest)
        Log.info("Photo listings count: \(listings.count)", domain: .metadata)
        let batches = listings.splitInGroups(of: 100)
        try batches.enumerated().forEach { index, batch in
            Log.info("Deleting photo listings from legacy photos share. \(index + 1). batch out of \(batches.count)", domain: .metadata)
            batch.forEach {
                self.managedObjectContext.delete($0)
            }
            try self.managedObjectContext.saveOrRollback()
        }
        try self.managedObjectContext.saveOrRollback()
    }

    private func deletePhotosMetadata(root: Folder) throws {
        let photosInRoot = Array(root.children)
        let batches = photosInRoot.splitInGroups(of: 100)
        try batches.enumerated().forEach { index, batch in
            Log.info("Deleting photos from legacy photos share. \(index + 1). batch out of \(batches.count)", domain: .metadata)
            batch.forEach {
                self.managedObjectContext.delete($0)
            }
            try self.managedObjectContext.saveOrRollback()
        }
    }
}
