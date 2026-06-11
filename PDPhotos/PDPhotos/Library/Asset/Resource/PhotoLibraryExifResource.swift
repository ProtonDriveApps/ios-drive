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

public  protocol PhotoLibraryExifResource {
    func getCameraInfo(asset: AVAsset) async -> PhotoAssetMetadata.Camera
    func getCameraInfo(at url: URL, isVideo: Bool) async -> PhotoAssetMetadata.Camera
    func getCameraInfo(from properties: NSDictionary) -> PhotoAssetMetadata.Camera
    func getLocation(at url: URL, isVideo: Bool) async -> PhotoAssetMetadata.Location?
    func getLocation(asset: AVAsset) async -> PhotoAssetMetadata.Location?
    func getLocation(from properties: NSDictionary) -> PhotoAssetMetadata.Location?
    func getPhotoExif(at url: URL) -> PhotoAsset.Exif
    func getVideoExif(at url: URL) async -> PhotoAsset.Exif
}

public  enum PhotoLibraryExifResourceError: Error {
    case invalidSource
    case missingProperties
}

public final class CoreImagePhotoLibraryExifResource: PhotoLibraryExifResource {
    private let parser: PhotoLibraryExifParser

    public init(parser: PhotoLibraryExifParser) {
        self.parser = parser
    }

    public func getCameraInfo(at url: URL, isVideo: Bool) async -> PhotoAssetMetadata.Camera {
        if isVideo {
            return await parser.parseCameraInfo(at: url)
        } else {
            let dictionary = getPropertiesDictionary(at: url)
            return getCameraInfo(from: dictionary)
        }
    }

    public func getCameraInfo(asset: AVAsset) async -> PhotoAssetMetadata.Camera {
        return await parser.parseCameraInfo(from: asset)
    }

    public func getCameraInfo(from properties: NSDictionary) -> PhotoAssetMetadata.Camera {
        parser.parseCameraInfo(from: properties)
    }

    public func getLocation(at url: URL, isVideo: Bool) async -> PhotoAssetMetadata.Location? {
        if isVideo {
            let stringValue = await getVideoLocation(at: url)
            return parser.parseLocationFrom(stringValue: stringValue)
        } else {
            let dictionary = getPropertiesDictionary(at: url)
            return getLocation(from: dictionary)
        }
    }

    public func getLocation(asset: AVAsset) async -> PhotoAssetMetadata.Location? {
        let stringValue = await getVideoLocation(from: asset)
        return parser.parseLocationFrom(stringValue: stringValue)
    }

    public func getLocation(from properties: NSDictionary) -> PhotoAssetMetadata.Location? {
        parser.parseLocation(from: properties)
    }

    public func getPhotoExif(at url: URL) -> PhotoAsset.Exif {
        return Data()

        // We don't upload exif until the format is aligned.
        // EXIF in this context means metadata other than location, camera details ...etc
        //        let dictionary = getExifDictionary(at: url)
        //        return parser.parseExif(from: dictionary)
    }

    public func getVideoExif(at url: URL) async -> PhotoAsset.Exif {
        return Data()

        // We don't upload exif until the format is aligned.
        // EXIF in this context means metadata other than location, camera details ...etc
        //        let items = (try? await getVideoMetadataItems(at: url)) ?? []
        //        var dictionary = [String: Any]()
        //        items.forEach { item in
        //            if let key = item.key as? String {
        //                dictionary[key] = item.stringValue
        //            }
        //        }
        //        let exif = try? JSONSerialization.data(withJSONObject: dictionary)
        //        return exif ?? Data()
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

    private func getPropertiesDictionary(at url: URL) -> NSDictionary {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return [:]
        }
        guard let dictionary = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            return [:]
        }
        return dictionary as NSDictionary
    }

    private func getVideoLocation(at url: URL) async -> String? {
        let asset = AVAsset(url: url)
        return await getVideoLocation(from: asset)
    }

    private func getVideoLocation(from asset: AVAsset) async -> String? {
        do {
            let metadata = try await asset.load(.metadata)

            guard
                let locationMetadata = metadata.first(where: { $0.commonKey?.rawValue == "location" })
            else { return nil }
            return try await locationMetadata.load(.stringValue)
        } catch {
            Log.error("Failed to get video location", error: error, domain: .photosProcessing)
            return nil
        }
    }
}

/// Only for QA to do test
public final class PartialPhotoLibraryExifResource: PhotoLibraryExifResource {
    
    public init() { }

    public func getCameraInfo(at url: URL, isVideo: Bool) async -> PhotoAssetMetadata.Camera {
        let dictionary = getExifDictionary(at: url)
        let exifDictionary = dictionary[kCGImagePropertyExifDictionary] as? NSDictionary ?? [:]
        return getCameraInfo(from: exifDictionary)
    }

    public func getCameraInfo(asset: AVAsset) async -> PDCore.PhotoAssetMetadata.Camera {
        var creationDate: Date?
        var isFrontCamera = false
        do {
            let (metadata, tracks) = try await asset.load(.metadata, .tracks)

            let dateMetadata = metadata.first(where: { $0.commonKey?.rawValue == "creationDate" })
            let dateString = try await dateMetadata?.load(.stringValue)
            creationDate = ISO8601DateFormatter.default.date(dateString)

            for track in tracks {
                guard
                    let quickTimeMetadata = try? await track.loadMetadata(for: .quickTimeMetadata),
                    let lens = quickTimeMetadata.first(where: { $0.identifier?.rawValue.contains("lens_model") ?? false }),
                    let stringValue = try await lens.load(.stringValue)
                else { continue }
                if stringValue.contains("front") {
                    isFrontCamera = true
                }
                break
            }
        } catch {
            Log.error("Failed to get video camera information", error: error, domain: .photosProcessing)
        }
        return PhotoAssetMetadata.Camera(
            captureTime: creationDate,
            device: nil,
            orientation: nil, // Can't find related info
            subjectCoordinates: nil, // Video doesn't have it
            isFrontCamera: isFrontCamera
        )
    }

    public func getCameraInfo(from exifDictionary: NSDictionary) -> PDCore.PhotoAssetMetadata.Camera {
        let cameraTime = CameraCaptureTimeParser().parseCameraCaptureTime(fromExif: exifDictionary)
        let isFrontCamera = (exifDictionary[kCGImagePropertyExifLensModel] as? String)?.contains("front") ?? false
        return PhotoAssetMetadata.Camera(
            captureTime: cameraTime.captureTime,
            device: nil,
            modificationTime: cameraTime.modificationTime,
            orientation: nil,
            subjectCoordinates: nil,
            isFrontCamera: isFrontCamera
        )
    }

    public func getLocation(from exif: NSDictionary) -> PDCore.PhotoAssetMetadata.Location? {
        nil
    }

    public func getLocation(asset: AVAsset) -> PDCore.PhotoAssetMetadata.Location? {
        nil
    }

    public func getLocation(at url: URL, isVideo: Bool) async -> PhotoAssetMetadata.Location? {
        return nil
    }

    public func getPhotoExif(at url: URL) -> PhotoAsset.Exif {
        return Data()
    }

    public func getVideoExif(at url: URL) async -> PhotoAsset.Exif {
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
