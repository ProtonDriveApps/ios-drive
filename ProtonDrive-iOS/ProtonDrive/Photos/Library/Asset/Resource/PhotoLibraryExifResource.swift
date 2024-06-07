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
    func getCameraInfo(at url: URL) -> PhotoAssetMetadata.Camera
    func getLocation(at url: URL) -> PhotoAssetMetadata.Location?
    func getPhotoExif(at url: URL) -> PhotoAsset.Exif
    func getVideoExif(at url: URL) async -> PhotoAsset.Exif
}

enum PhotoLibraryExifResourceError: Error {
    case invalidSource
    case missingProperties
}

final class CoreImagePhotoLibraryExifResource: PhotoLibraryExifResource {
    private let parser: PhotoLibraryExifParser

    init(parser: PhotoLibraryExifParser) {
        self.parser = parser
    }

    func getCameraInfo(at url: URL) -> PhotoAssetMetadata.Camera {
        let dictionary = getExifDictionary(at: url)
        return parser.parseCameraInfo(from: dictionary)
    }

    func getLocation(at url: URL) -> PhotoAssetMetadata.Location? {
        let dictionary = getExifDictionary(at: url)
        return parser.parseLocation(from: dictionary)
    }

    func getPhotoExif(at url: URL) -> PhotoAsset.Exif {
        let dictionary = getExifDictionary(at: url)
        return parser.parseExif(from: dictionary)
    }

    func getVideoExif(at url: URL) async -> PhotoAsset.Exif {
        let items = (try? await getVideoMetadataItems(at: url)) ?? []
        var dictionary = [String: Any]()
        items.forEach { item in
            if let key = item.key as? String {
                dictionary[key] = item.stringValue
            }
        }
        let exif = try? JSONSerialization.data(withJSONObject: dictionary)
        return exif ?? Data()
    }

    private func getVideoMetadataItems(at url: URL) async throws -> [AVMetadataItem] {
        let asset = AVAsset(url: url)
        let metadata = try await asset.load(.metadata)
        let commonMetadata = try await asset.load(.commonMetadata)
        let availableFormats = try await asset.load(.availableMetadataFormats)
        var allItems = metadata + commonMetadata
        for format in availableFormats {
            allItems += try await asset.loadMetadata(for: format)
        }
        return allItems
    }

    private func getExifDictionary(at url: URL) -> NSDictionary {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return [:]
        }
        guard let dictionary = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            return [:]
        }
        return dictionary as NSDictionary
    }
}

final class PartialPhotoLibraryExifResource: PhotoLibraryExifResource {
    func getCameraInfo(at url: URL) -> PhotoAssetMetadata.Camera {
        let dictionary = getExifDictionary(at: url)
        let exifDictionary = dictionary[kCGImagePropertyExifDictionary] as? NSDictionary ?? [:]
        let cameraTime = CameraCaptureTimeParser().parseCameraCaptureTime(fromExif: exifDictionary)
        return PhotoAssetMetadata.Camera(
            captureTime: cameraTime.captureTime,
            device: nil,
            modificationTime: cameraTime.modificationTime,
            orientation: nil,
            subjectCoordinates: nil
        )
    }

    func getLocation(at url: URL) -> PhotoAssetMetadata.Location? {
        return nil
    }

    func getPhotoExif(at url: URL) -> PhotoAsset.Exif {
        return Data()
    }

    func getVideoExif(at url: URL) async -> PhotoAsset.Exif {
        return Data()
    }

    private func getExifDictionary(at url: URL) -> NSDictionary {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return [:]
        }
        guard let dictionary = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            return [:]
        }
        return dictionary as NSDictionary
    }
}
