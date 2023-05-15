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

struct PhotoAsset: Equatable {
    let url: URL
    let filename: String
    let filenameHash: String
    let contentHash: String
    let exif: [String: String]
    let metadata: Metadata

    struct Metadata: Equatable {
        let cloudIdentifier: String
        let creationDate: Date?
        let modifiedDate: Date?
    }
}

typealias PhotoAssets = [PhotoAsset]

struct PhotoAssetCompound: Equatable {
    let primary: PhotoAsset
    let secondary: PhotoAssets
}
