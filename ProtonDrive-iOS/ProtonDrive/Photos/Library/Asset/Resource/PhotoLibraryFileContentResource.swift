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
import PDCore
import Photos

protocol PhotoLibraryFileContentResource {
    func copyFile(with resource: PHAssetResource) async throws -> URL
    func getVideoDuration(at url: URL) -> Double
}

final class LocalPhotoLibraryFileContentResource: PhotoLibraryFileContentResource {
    func copyFile(with resource: PHAssetResource) async throws -> URL {
        do {
            let filename = try resource.getNormalizedFilename()
            let url = PDFileManager.prepareUrlForPhotoFile(named: filename)
            let options = makeOptions()
            try await PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options)
            return url
        } catch let error as NSError {
            throw DomainCodeError(error: error)
        }
    }

    func getVideoDuration(at url: URL) -> Double {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        return CMTimeGetSeconds(duration)
    }

    private func makeOptions() -> PHAssetResourceRequestOptions {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        return options
    }
}
