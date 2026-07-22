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

final class UploadingPhotosBootstrapper: AppBootstrapper {
    private let skippableCache: PhotosSkippableCache
    private let storage: StorageManager
    private let tower: Tower

    init(skippableCache: PhotosSkippableCache, storage: StorageManager, tower: Tower) {
        self.skippableCache = skippableCache
        self.storage = storage
        self.tower = tower
    }

    func bootstrap() async throws {
        try await measure(message: "uploading photos bootstrap", domain: .applicationBootstrap) {
            try await storage.backgroundContextPool.performInContext { [weak self] context in
                guard
                    let self,
                    storage.getPhotosVolumeId(in: context) != nil // New login or clear cache
                else { return }

                self.deleteCorruptedUploadingPhotos(moc: context)
                self.resetUploadingPhotoState(moc: context)
                try context.saveIfNeeded()
            }
        }
    }
    
    private func deleteCorruptedUploadingPhotos(moc: NSManagedObjectContext) {
        let corruptedPhotos = storage.fetchCorruptedUploadingPhotos(moc: moc)
        if corruptedPhotos.isEmpty {
            Log.debug("No corrupted photos found in cache. ✅", domain: .storage)
        } else {
            // This can happen after updating to version >= 1.54.1. It should happen only once though.
            Log.debug("Removing \(corruptedPhotos.count) corrupted uploading photos (nil `nameSignatureEmail`)", domain: .storage)
            corruptedPhotos.forEach { moc.delete($0) }
            skippableCache.clean()
        }
    }
    
    private func resetUploadingPhotoState(moc: NSManagedObjectContext) {
        let recoverablePhotos = storage.fetchPhotosForInterruptedStateRecovery(moc: moc)
        if recoverablePhotos.isEmpty {
            Log.debug("No recoverable uploading photos found in cache. ✅", domain: .storage)
        } else {
            Log.info("Reset upload states to interrupted for \(recoverablePhotos.count) photos", domain: .storage)
            recoverablePhotos.forEach { $0.state = .interrupted }
        }
    }
}
