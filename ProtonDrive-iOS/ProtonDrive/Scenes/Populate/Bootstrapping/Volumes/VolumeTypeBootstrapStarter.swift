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
import Foundation
import PDCore

final class VolumeTypeBootstrapStarter: AppBootstrapper {
    private let storage: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(storage: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.storage = storage
        self.managedObjectContext = managedObjectContext
    }

    func bootstrap() async throws {
        try await managedObjectContext.perform {
            var volumes = self.storage.volumes(moc: self.managedObjectContext)

            if let mainVolumeIndex = volumes.firstIndex(where: { $0.shares.contains(where: { $0.type == .main }) }) {
                // Need to remove main volume from the array, otherwise wrong volume may be found below (due to legacy photo share)
                let mainVolume = volumes.remove(at: mainVolumeIndex)
                self.updateVolumeIfNeeded(volume: mainVolume, type: .main)
            }
            if let photoVolume = volumes.first(where: { $0.shares.contains(where: { $0.type == .photos }) }) {
                self.updateVolumeIfNeeded(volume: photoVolume, type: .photo)
            }

            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func updateVolumeIfNeeded(volume: Volume, type: Volume.VolumeType) {
        if volume.type != type {
            volume.type = type
        }
    }
}
