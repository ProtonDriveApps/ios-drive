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
import CoreData

public protocol ExistingPhotoCompoundRepository {
    func  getExistingCompound(_ compound: RawExistingCompound) async throws -> ExistingCompound
}

public struct ExistingCompound {
    let mainPhoto: Photo
    let assets: PhotoAssets
    
    public init(mainPhoto: Photo, assets: PhotoAssets) {
        self.mainPhoto = mainPhoto
        self.assets = assets
    }
}

public struct RawExistingCompound {
    let volumeID: String
    let shareID: String
    let mainPhotoID: String
    let assets: PhotoAssets
    
    public init(shareID: String, mainPhotoID: String, assets: PhotoAssets, volumeID: String) {
        self.shareID = shareID
        self.mainPhotoID = mainPhotoID
        self.assets = assets
        self.volumeID = volumeID
    }
}

public struct RemoteCachingExistingPhotoCompoundRepository: ExistingPhotoCompoundRepository {
    private let nodeCacheService: NodeFetchAndCacheService
    private let cachedPhotoRepository: CachedPhotoRepository
    
    public init(nodeCacheService: NodeFetchAndCacheService, cachedPhotoRepository: CachedPhotoRepository) {
        self.nodeCacheService = nodeCacheService
        self.cachedPhotoRepository = cachedPhotoRepository
    }
    
    public func getExistingCompound(_ compound: RawExistingCompound) async throws -> ExistingCompound {
        let id = NodeIdentifier(compound.mainPhotoID, compound.shareID, compound.volumeID)
        try await nodeCacheService.fetchAndCache(id)
        let photo = try cachedPhotoRepository.getPhoto(id)
        return ExistingCompound(mainPhoto: photo, assets: compound.assets)
    }
}
