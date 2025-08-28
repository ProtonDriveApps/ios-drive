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

struct AddPhotosToAlbumControllerFactory {
    func makeController(tower: Tower, managedObjectContext: NSManagedObjectContext) -> AddPhotosToAlbumControllerProtocol {
        let albumOwnershipRepository = AlbumOwnershipRepository(managedObjectContext: managedObjectContext, storageManager: tower.storage)
        let interactor = AddPhotosToAlbumInteractor(
            albumOwnershipRepository: albumOwnershipRepository,
            addInteractor: AlbumGalleryFactory().makeAddPhotosToOwnAlbumInteractor(
                managedObjectContext: managedObjectContext,
                tower: tower
            ),
            copyInteractor: CopyPhotosControllerFactory().makeCopyPhotosInteractor(tower: tower, context: managedObjectContext)
        )
        let facade = AddPhotosToAlbumFacade(interactor: interactor)
        let userMessageHandler = UserMessageHandler()
        let operationsMessageHandler = AlbumContentOperationMessenger(userMessageHandler: userMessageHandler)
        let messageHandler = AddPhotosToAlbumMessageHandler(
            messageHandler: userMessageHandler,
            operationMessageHandler: operationsMessageHandler,
            copyMessageHandler: CopyPhotosMessageHandler(messageHandler: operationsMessageHandler)
        )
        return AddPhotosToAlbumController(
            eventsController: tower,
            facade: facade,
            messageHandler: messageHandler
        )
    }
}
