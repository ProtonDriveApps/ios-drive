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

import Photos

protocol PhotoLibraryNameResource {
    func getFilename(from resources: [PHAssetResource]) throws -> String
    func getPhotoFilename(from resources: [PHAssetResource]) throws -> String
    func getPairedVideoFilename(from resources: [PHAssetResource]) throws -> String
}

final class PHAssetNameResource: PhotoLibraryNameResource {
    func getFilename(from resources: [PHAssetResource]) throws -> String {
        return try getFilename(from: resources, types: [.photo, .fullSizePhoto, .video, .fullSizeVideo])
    }

    func getPhotoFilename(from resources: [PHAssetResource]) throws -> String {
        return try getFilename(from: resources, types: [.photo, .fullSizePhoto])
    }

    func getPairedVideoFilename(from resources: [PHAssetResource]) throws -> String {
        return try getFilename(from: resources, types: [.pairedVideo])
    }

    private func getFilename(from resources: [PHAssetResource], types: Set<PHAssetResourceType>) throws -> String {
        let resource = resources.first { types.contains($0.type) } ?? resources.first
        guard let primaryResource = resource else {
            throw PhotoLibraryMappingResourceError.invalidAsset
        }
        return try primaryResource.getNormalizedFilename()
    }
}
