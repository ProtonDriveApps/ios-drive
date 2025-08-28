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

public protocol PhotoLibraryExifParser {
    func parseCameraInfo(from dictionary: NSDictionary) -> PhotoAssetMetadata.Camera
    func parseCameraInfo(at url: URL) async -> PhotoAssetMetadata.Camera
    func parseLocation(from dictionary: NSDictionary) -> PhotoAssetMetadata.Location?
    func parseLocationFrom(stringValue: String?) -> PhotoAssetMetadata.Location?
    func parseExif(from dictionary: NSDictionary) -> PhotoAsset.Exif
}

public enum CoreImagePhotoLibraryExifParserError: Error {
    case missingAttribute
}

public final class CoreImagePhotoLibraryExifParser: PhotoLibraryExifParser {
    private let locationRegex: NSRegularExpression

    public init() {
        locationRegex = NSRegularExpression(#"[\+\-]\d+.\d+"#)
    }

    public func parseCameraInfo(from dictionary: NSDictionary) -> PhotoAssetMetadata.Camera {
        let exif = dictionary[kCGImagePropertyExifDictionary] as? NSDictionary ?? [:]
        let tiff = dictionary[kCGImagePropertyTIFFDictionary] as? NSDictionary
        let cameraTime = CameraCaptureTimeParser().parseCameraCaptureTime(fromExif: exif)
        let device = tiff?[kCGImagePropertyTIFFModel] as? String
        let orientation = tiff?[kCGImagePropertyTIFFOrientation] as? Int
        let subjectCoordinatesDictionary = exif[kCGImagePropertyExifSubjectArea] as? NSDictionary ?? [:]
        let subjectCoordinates = try? parseSubjectCoordinates(from: subjectCoordinatesDictionary)
        let isFrontCamera = (exif[kCGImagePropertyExifLensModel] as? String)?.contains("front") ?? false
        return PhotoAssetMetadata.Camera(
            captureTime: cameraTime.captureTime,
            device: device,
            modificationTime: cameraTime.modificationTime,
            orientation: orientation,
            subjectCoordinates: subjectCoordinates,
            isFrontCamera: isFrontCamera
        )
    }

    public func parseCameraInfo(at url: URL) async -> PhotoAssetMetadata.Camera {
        var creationDate: Date?
        var modelString: String?
        var isFrontCamera = false
        do {
            let asset = AVAsset(url: url)
            let (metadata, tracks) = try await asset.load(.metadata, .tracks)

            let dateMetadata = metadata.first(where: { $0.commonKey?.rawValue == "creationDate" })
            let dateString = try await dateMetadata?.load(.stringValue)
            creationDate = ISO8601DateFormatter().date(dateString)

            let modelMetadata = metadata.first(where: { $0.commonKey?.rawValue == "model" })
            modelString = try await modelMetadata?.load(.stringValue)

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
            device: modelString,
            orientation: nil, // Can't find related info
            subjectCoordinates: nil, // Video doesn't have it
            isFrontCamera: isFrontCamera
        )
    }

    public func parseLocation(from dictionary: NSDictionary) -> PhotoAssetMetadata.Location? {
        let gps = dictionary[kCGImagePropertyGPSDictionary] as? NSDictionary
        guard let latitude = gps?[kCGImagePropertyGPSLatitude] as? Double else {
            return nil
        }
        guard let longitude = gps?[kCGImagePropertyGPSLongitude] as? Double else {
            return nil
        }
        return PhotoAssetMetadata.Location(latitude: latitude, longitude: longitude)
    }

    public func parseLocationFrom(stringValue: String?) -> PhotoAssetMetadata.Location? {
        guard let input = stringValue else { return nil }
        // Apple stores GPS as a string like: "±37.3317±122.0307±0.0000/"
        let nsrange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = locationRegex.matches(in: input, options: [], range: nsrange)

        let results = matches.compactMap { match -> Double? in
            if let range = Range(match.range, in: input) {
                return Double(input[range])
            }
            return nil
        }
        guard results.count == 3 else { return nil }
        return PhotoAssetMetadata.Location(latitude: results[0], longitude: results[1])
    }

    public func parseExif(from dictionary: NSDictionary) -> PhotoAsset.Exif {
        var result = [String: Any]()
        dictionary.forEach { key, value in
            guard let dictionary = value as? NSDictionary else { return }
            guard (key as? String) != kCGImagePropertyMakerAppleDictionary as String else { return }
            let parsedDictionary = parse(dictionary: dictionary)
            result.merge(parsedDictionary, uniquingKeysWith: { $1 })
        }
        let data = try? JSONSerialization.data(withJSONObject: result)
        return data ?? Data()
    }

    private func parse(dictionary: NSDictionary) -> [String: Any] {
        var result = [String: Any]()
        dictionary.forEach { key, value in
            guard let stringKey = key as? String else { return }
            result[stringKey] = value
        }
        return result
    }

    private func parseSubjectCoordinates(from dictionary: NSDictionary) throws -> PhotoAssetMetadata.SubjectCoordinates {
        guard dictionary.count == 4 else {
            throw CoreImagePhotoLibraryExifParserError.missingAttribute
        }

        let centerX = dictionary[0] as? Int ?? 0
        let centerY = dictionary[1] as? Int ?? 0
        let width = dictionary[2] as? Int ?? 0
        let height = dictionary[3] as? Int ?? 0
        return PhotoAssetMetadata.SubjectCoordinates(
            top: centerY - height / 2,
            left: centerX - width / 2,
            bottom: centerY + height / 2,
            right: centerX + width / 2
        )
    }
}
