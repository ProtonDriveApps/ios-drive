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

enum LocalPhotosVolumeResult {
    case photoVolume(VolumeID)
    case legacyPhotoShare(VolumeID)
    case notEnoughData
}

protocol LocalPhotosVolumeFetchResourceProtocol {
    func getLocalState() throws -> LocalPhotosVolumeResult
}

final class LocalPhotosVolumeFetchResource: LocalPhotosVolumeFetchResourceProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func getLocalState() throws -> LocalPhotosVolumeResult {
        do {
            let photoVolumeId = try storageManager.getPhotosVolumeId(in: managedObjectContext) ?! "Missing photo volume"
            return .photoVolume(photoVolumeId)
        } catch {
            // Check if old photo share exists
            return try managedObjectContext.performAndWait {
                let shares = try storageManager.fetchShares(moc: managedObjectContext)
                if let legacyPhotoShare = shares.first(where: { $0.type == .photos }) {
                    // Old type photo share exists
                    return .legacyPhotoShare(legacyPhotoShare.volumeID)
                } else {
                    // There's no photo share in local DB
                    return .notEnoughData
                }
            }
        }
    }
}

