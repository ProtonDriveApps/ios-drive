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

struct CopyPhotosControllerFactory {
    func makeCopyPhotosController(tower: Tower, context: NSManagedObjectContext, albumId: AnyVolumeIdentifier) -> CopyPhotosToStreamControllerProtocol {
        let interactor = makeCopyPhotosInteractor(tower: tower, context: context)
        let handler = UserMessageHandler()
        let rootFolderIdRepository = PhotoVolumeRootFolderIdRepository(
            storageManager: tower.storage,
            managedObjectContext: context
        )
        let listConfiguration = PhotosListConfiguration(volumeId: albumId.volumeID, albumId: albumId.id)
        let fetchInteractor = PhotosListFetchingControllerFactory().makeInteractor(
            tower: tower,
            configuration: listConfiguration,
            managedObjectContext: context
        )
        let metadataRepository = PDPhotosFactory().makeRemoteMetadataFetchRepository(tower: tower, managedObjectContext: context)
        let albumChildrenInteractor = AlbumAllChildrenInteractor(
            fetchInteractor: fetchInteractor,
            metadataRepository: metadataRepository
        )
        return CopyPhotosToStreamController(
            dependencies: .init(
                copyMessageHandler: CopyPhotosMessageHandler(
                    messageHandler: PhotoStreamMoveOperationMessageHandler(userMessageHandler: handler)
                ),
                copyPhotosInteractor: interactor,
                rootFolderIdRepository: rootFolderIdRepository,
                albumChildrenInteractor: albumChildrenInteractor,
                eventsSystemManager: tower,
                userMessageHandler: handler
            )
        )
    }

    func makeCopyPhotosInteractor(tower: Tower, context: NSManagedObjectContext) -> CopyPhotosInteractor {
        let duplicateCheckRepository = PhotosDuplicateCheckRepositoryFactory().makeRepository(
            tower: tower,
            managedObjectContext: context
        )
        return CopyPhotosInteractor(
            dependencies: .init(
                albumReader: NodeWithHashKeyReader(),
                client: tower.client,
                context: context,
                encryptor: Encryptor(),
                photoReader: PhotoReader(),
                signersKitFactory: tower.sessionVault,
                duplicateCheckRepository: duplicateCheckRepository
            )
        )
    }
}
