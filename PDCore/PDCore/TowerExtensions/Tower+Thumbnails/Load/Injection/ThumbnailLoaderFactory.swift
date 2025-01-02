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
import PDClient

public struct ThumbnailLoaderFactory {
    public init() {}
    
    func makeFileThumbnailLoader(storage: StorageManager, cloudSlot: CloudSlotProtocol, client: PDClient.Client) -> CancellableThumbnailLoader {
        let repository = FileNodeThumbnailRepository(store: storage)
        let typeStrategy = DefaultThumbnailTypeStrategy()
        return makeLoader(storage: storage, cloudSlot: cloudSlot, client: client, repository: repository, typeStrategy: typeStrategy)
    }

    public func makePhotoSmallThumbnailLoader(tower: Tower) -> ThumbnailLoader {
        let typeStrategy = DefaultThumbnailTypeStrategy()
        let repository = PhotoNodeThumbnailRepository(store: tower.storage, typeStrategy: typeStrategy)
        return makeLoader(storage: tower.storage, cloudSlot: tower.cloudSlot, client: tower.client, repository: repository, typeStrategy: typeStrategy)
    }

    public func makePhotoBigThumbnailLoader(tower: Tower) -> ThumbnailLoader {
        let typeStrategy = PhotoBigThumbnailTypeStrategy()
        let repository = PhotoNodeThumbnailRepository(store: tower.storage, typeStrategy: typeStrategy)
        return makeLoader(storage: tower.storage, cloudSlot: tower.cloudSlot, client: tower.client, repository: repository, typeStrategy: typeStrategy)
    }

    private func makeLoader(storage: StorageManager, cloudSlot: CloudSlotProtocol, client: PDClient.Client, repository: NodeThumbnailRepository, typeStrategy: ThumbnailTypeStrategy) -> DispatchedAsyncThumbnailLoader {
        let thumbnailsOperatiosFactory = LoadThumbnailOperationsFactory(store: storage, cloud: cloudSlot, client: client, thumbnailRepository: repository, typeStrategy: typeStrategy)
        let asyncLoader = AsyncThumbnailLoader(operationsFactory: thumbnailsOperatiosFactory)
        return DispatchedAsyncThumbnailLoader(thumbnailLoader: asyncLoader)
    }
}
