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

import AVFoundation
import Foundation
import ImageIO
import PDCore

protocol PhotoLibraryExifResource {
    func getPhotoExif(at url: URL) throws -> PhotoAsset.Exif
    func getVideoExif(at url: URL) async throws -> PhotoAsset.Exif
}

enum PhotoLibraryExifResourceError: Error {
    case invalidSource
    case missingProperties
}

final class LocalPhotoLibraryExifResource: PhotoLibraryExifResource {
    func getPhotoExif(at url: URL) throws -> PhotoAsset.Exif {
        // TODO: need to specify exact keys and values format / or if this is the way to extract the keys
        return PhotoAsset.Exif()
//        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
//            throw PhotoLibraryExifResourceError.invalidSource
//        }
//        guard let dictionary = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
//            throw PhotoLibraryExifResourceError.missingProperties
//        }
//        return parse(dictionary)
    }

    func getVideoExif(at url: URL) async throws -> PhotoAsset.Exif {
        // TODO: need to specify exact keys and values format / or if this is the way to extract the keys
        return PhotoAsset.Exif()
//        let asset = AVAsset(url: url)
//        var allMetadata = [AVMetadataItem]()
//        for format in try await asset.load(.availableMetadataFormats) {
//            allMetadata += try await asset.loadMetadata(for: format)
//        }
//        return parse(allMetadata)
    }

//    private func parse(_ dictionary: CFDictionary) -> PhotoAsset.Exif {
//        let dictionary = dictionary as NSDictionary
//        let exifDictionary = dictionary[kCGImagePropertyExifDictionary]
//        return [:]
//    }

//    private func parse(_ metadata: [AVMetadataItem]) -> PhotoAsset.Exif {
//        var exif = PhotoAsset.Exif()
//        metadata.forEach { item in
//            if let key = item.key as? String {
//                exif[key] = item.stringValue
//            }
//        }
//        return exif
//    }
}
