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

import PDCore
import CoreData

final class CoredataCleanPhotoLeftoversCommand: Command {
    let storage: StorageManager
    let moc: NSManagedObjectContext
    
    init(storage: StorageManager, moc: NSManagedObjectContext) {
        self.storage = storage
        self.moc = moc
    }
    
    func execute() {
        do {
            try moc.performAndWait {
                let fetchRequest = self.storage.requestUploadingPhotos()
                let photos = (try? moc.fetch(fetchRequest)) ?? []

                photos.forEach { self.moc.delete($0) }

                try self.moc.saveOrRollback()
            }
        } catch {
            Log.error(DriveError(error), domain: .uploader)
        }
    }
}
