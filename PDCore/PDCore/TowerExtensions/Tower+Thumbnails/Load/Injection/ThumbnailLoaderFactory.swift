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

public struct ThumbnailLoaderFactory {
    public init() {}
    
    func makeFileThumbnailLoader(storage: StorageManager, cloudSlot: CloudSlot) -> CancellableThumbnailLoader {
        let repository = FileThumbnailRepository(store: storage)
        return makeLoader(storage: storage, cloudSlot: cloudSlot, repository: repository)
    }

    public func makePhotoSmallThumbnailLoader(tower: Tower) -> ThumbnailLoader {
        let repository = PhotoSmallThumbnailRepository(store: tower.storage)
        return makeLoader(storage: tower.storage, cloudSlot: tower.cloudSlot, repository: repository)
    }

    public func makePhotoBigThumbnailLoader(tower: Tower) -> ThumbnailLoader {
        let repository = PhotoBigThumbnailRepository(store: tower.storage)
        return makeLoader(storage: tower.storage, cloudSlot: tower.cloudSlot, repository: repository)
    }

    private func makeLoader(storage: StorageManager, cloudSlot: CloudSlot, repository: ThumbnailRepository) -> DispatchedAsyncThumbnailLoader {
        let thumbnailsOperatiosFactory = LoadThumbnailOperationsFactory(store: storage, cloud: cloudSlot, thumbnailRepository: repository)
        let asyncLoader = AsyncThumbnailLoader(operationsFactory: thumbnailsOperatiosFactory)
        return DispatchedAsyncThumbnailLoader(thumbnailLoader: asyncLoader)
    }
}
