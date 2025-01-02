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
import Photos

enum PhotoLibraryLivePhotoFilesResourceError: Error {
    // ([Int], String): Contained resource type, additional PHAsset info
    case invalidResources([Int], String)
}

extension PhotoLibraryLivePhotoFilesResourceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .invalidResources(types, info):
            return "PhotoLibraryLivePhotoFilesResourceError \(types), source: \(info)"
        }
    }
}

final class PhotoLibraryLivePhotoCompoundResource: PhotoLibraryCompoundResource {
    private let liveCompoundResource: PhotoLibraryLivePairCompoundResource

    init(liveCompoundResource: PhotoLibraryLivePairCompoundResource) {
        self.liveCompoundResource = liveCompoundResource
    }

    func execute(with identifier: PhotoIdentifier, asset: PHAsset) async throws -> [PhotoAssetCompound] {
        return [
            try await liveCompoundResource.getOriginal(with: identifier, asset: asset),
            try? await liveCompoundResource.getModified(with: identifier, asset: asset)
        ].compactMap { $0 }
    }
}
