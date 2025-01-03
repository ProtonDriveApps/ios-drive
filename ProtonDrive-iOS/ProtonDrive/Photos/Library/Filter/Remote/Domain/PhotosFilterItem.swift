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

struct PhotosFilterItem: Equatable {
    let primary: PhotoAssetIdentifier
    let secondary: [PhotoAssetIdentifier]

    var allIdentifiers: [PhotoAssetIdentifier] {
        [primary] + secondary
    }

    var compound: PhotoAssetCompound {
        PhotoAssetCompound(primary: primary.asset, secondary: secondary.map(\.asset))
    }
}

struct PhotosFilterCompounds {
    let items: [PhotosFilterItem]
    let failedCompounds: [PhotosFailedCompound]
}

struct PhotosFailedCompound {
    let compound: PhotoAssetCompound
    let error: PhotosFailureUserError
    
    init(compound: PhotoAssetCompound, error: PhotosFailureUserError = .unknown) {
        self.compound = compound
        self.error = error
    }
}

struct PhotoHashes: Equatable, Hashable {
    let nameHash: String
    let contentHash: String
}

struct PartialPhotoAssetCompound: Equatable {
    let primaryLinkId: String
    let secondary: [PhotoAsset]
    let originalCompound: PhotoAssetCompound
}
