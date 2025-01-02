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

public class LocalCoredataLastPhotoRepository: LastPhotoRepository {
    private let moc: NSManagedObjectContext
    private let storage: StorageManager

    public init(moc: NSManagedObjectContext, storage: StorageManager) {
        self.moc = moc
        self.storage = storage
    }

    public func getLastPhotoID() throws -> String {
        try moc.performAndWait {
            let volumeId = try storage.getMyVolumeId(in: moc)
            guard let lastPhotoID = try storage.fetchLastPrimaryPhoto(volumeId: volumeId, moc: moc)?.photoRevision.decryptedExtendedAttributes().iOSPhotos?.iCloudID else {
                throw InvalidLastPhotoError()
            }
            return lastPhotoID
        }
    }

    struct InvalidLastPhotoError: Error { }
}
