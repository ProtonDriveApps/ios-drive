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

import Foundation

public struct PhotoImportFactory {
    public init() {}

    public func makeImporter(tower: Tower) -> PhotoCompoundImporter {
        let managedObjectContext = tower.storage.photosBackgroundContext
        let repositoriesFactory = PhotosRepositoriesFactory()
        let rootRepository = repositoriesFactory.makeRootFolderRepository(tower: tower)
        let photoImporter = CoreDataPhotoImporter(moc: managedObjectContext, signersKitFactory: tower.sessionVault, uploadClientUIDProvider: tower.sessionVault)
        let nodeCacheService = ClientNodeFetchAndCacheService(client: tower.client, cacher: tower.cloudSlot, context: tower.storage.photosBackgroundContext)
        let cachedPhotoRepository = CachedPhotoRepository(storageManager: tower.storage, photosContext: managedObjectContext)
        let existingPhotoRepository = RemoteCachingExistingPhotoCompoundRepository(nodeCacheService: nodeCacheService, cachedPhotoRepository: cachedPhotoRepository)
        return CompoundPhotoCompoundImporter(importer: photoImporter, notificationCenter: NotificationCenter.default, moc: managedObjectContext, rootRepository: rootRepository, existingPhotoRepository: existingPhotoRepository)
    }
}
