// Copyright (c) 2023 Proton AG
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

public final class StorageUploadingPhotosRepository: UploadingPrimaryPhotosRepository {
    let storage: StorageManager
    let moc: NSManagedObjectContext

    public init(storage: StorageManager, moc: NSManagedObjectContext) {
        self.storage = storage
        self.moc = moc
    }

    public func getPhotos() -> [Photo] {
        do {
            let volumeId = try storage.getPhotosVolumeId(in: moc) ?? storage.getMyVolumeId(in: moc)
            return storage.fetchUploadingPhotos(
                volumeId: volumeId,
                size: Constants.processingPhotoUploadsBatchSize,
                moc: moc
            )
        } catch {
            Log.error(error: error, domain: .photosUI)
            return []
        }
    }
    
    public func getPendingPhotosForSDK() -> [Photo] {
        let moc = storage.synchronousContextPool.acquire()
        defer { storage.synchronousContextPool.relinquish(moc) }
        
        do {
            let volumeId = try storage.getPhotosVolumeId(in: moc) ?? storage.getMyVolumeId(in: moc)
            return storage.fetchUploadingPhotosForSDK(
                volumeId: volumeId,
                size: Constants.processingPhotoUploadsBatchSize,
                moc: moc
            )
        } catch {
            Log.error(error: error, domain: .photosUI)
            return []
        }
    }

    public func deleteInterruptPhotos() async {
        await moc.perform { [moc, self] in
            do {
                let volumeID = storage.getPhotosVolumeId(in: moc) ?? ""
                let request = fetchInterruptedPhotos(volumeID: volumeID)
                let photos = try moc.fetch(request)
                photos.forEach { moc.delete($0) }
                try moc.saveIfNeeded()
            } catch {
                Log.error("Delete interrupt photos failed", error: error, domain: .uploader)
            }
        }
    }
}

extension StorageUploadingPhotosRepository {
    private func fetchInterruptedPhotos(volumeID: String) -> NSFetchRequest<CoreDataPhoto> {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Photo.captureTime), ascending: false)]
        fetchRequest.predicate = NSPredicate(
            format: "%K == %d AND %K == %@",
            #keyPath(Photo.stateRaw), Photo.State.interrupted.rawValue,
            #keyPath(Photo.volumeID), volumeID
        )
        return fetchRequest
    }
}
