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

struct PhotosListFetchingControllerFactory {
    func makeController(
        tower: Tower,
        configuration: PhotosListConfiguration,
        managedObjectContext: NSManagedObjectContext,
        anchorController: PhotosListAnchorControllerProtocol,
        errorController: ErrorSetControllerProtocol
    ) -> PhotosListFetchingControllerProtocol {
        let interactor = makeInteractor(
            tower: tower,
            configuration: configuration,
            managedObjectContext: managedObjectContext
        )
        let facade = AsyncPhotosListFetchingFacade(interactor: interactor)
        return PhotosListFetchingController(
            facade: facade,
            anchorController: anchorController,
            errorController: errorController,
            configuration: configuration
        )
    }

    func makeInteractor(
        tower: Tower,
        configuration: PhotosListConfiguration,
        managedObjectContext: NSManagedObjectContext
    ) -> PhotosListFetchingInteractor {
        let storeListingRepository = makeStoreListingRepository(managedObjectContext: managedObjectContext)
        return PhotosListFetchingInteractor(
            configuration: configuration,
            remoteListingRepository: tower.client,
            storeListingRepository: storeListingRepository
        )
    }

    func makeAnchorController() -> PhotosListAnchorControllerProtocol {
        PhotosListAnchorController(cache: PersistentPhotosListAnchorCache())
    }

    func makeInitialStatusController(fetchingController: PhotosListFetchingControllerProtocol) -> PhotosListFetchingStatusControllerProtocol {
        let statusController = PhotosListFetchingStatusController(fetchingController: fetchingController)
        return InitialPhotosListFetchingStatusController(statusController: statusController)
    }

    func makeStoreListingRepository(managedObjectContext: NSManagedObjectContext) -> CoreDataStorePhotoListingsRepository {
        let deleteListingRepository = CoreDataDeletePhotoListingsRepository(managedObjectContext: managedObjectContext)
        let storeListingRepository = CoreDataStorePhotoListingsRepository(managedObjectContext: managedObjectContext, deleteRepository: deleteListingRepository)
        return storeListingRepository
    }
}
