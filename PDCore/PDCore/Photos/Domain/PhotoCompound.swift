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

public struct PhotoAssetCompound: Equatable {

    public let primary: PhotoAsset
    public let secondary: PhotoAssets

    public init(primary: PhotoAsset, secondary: PhotoAssets) {
        self.primary = primary
        self.secondary = secondary
    }

    public var allAssets: PhotoAssets {
        [primary] + secondary
    }
}

public typealias PhotoAssets = [PhotoAsset]

public enum PhotoAssetCompoundType: Equatable {
    case new(PhotoAssetCompound)
    case existing(linkID: String, secondary: PhotoAssets)

    public var allAssets: PhotoAssets {
        switch self {
        case let .new(compound):
            return compound.allAssets
        case let .existing(_, secondary):
            return secondary
        }
    }
}
