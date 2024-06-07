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
import ImageIO
import PDCore

protocol PhotoLibraryExifParser {
    func parseCameraInfo(from dictionary: NSDictionary) -> PhotoAssetMetadata.Camera
    func parseLocation(from dictionary: NSDictionary) -> PhotoAssetMetadata.Location?
    func parseExif(from dictionary: NSDictionary) -> PhotoAsset.Exif
}

enum CoreImagePhotoLibraryExifParserError: Error {
    case missingAttribute
}

final class CoreImagePhotoLibraryExifParser: PhotoLibraryExifParser {
    func parseCameraInfo(from dictionary: NSDictionary) -> PhotoAssetMetadata.Camera {
        let exif = dictionary[kCGImagePropertyExifDictionary] as? NSDictionary ?? [:]
        let tiff = dictionary[kCGImagePropertyTIFFDictionary] as? NSDictionary
        let cameraTime = CameraCaptureTimeParser().parseCameraCaptureTime(fromExif: exif)
        let device = tiff?[kCGImagePropertyTIFFModel] as? String
        let orientation = tiff?[kCGImagePropertyTIFFOrientation] as? Int
        let subjectCoordinatesDictionary = exif[kCGImagePropertyExifSubjectArea] as? NSDictionary ?? [:]
        let subjectCoordinates = try? parseSubjectCoordinates(from: subjectCoordinatesDictionary)
        return PhotoAssetMetadata.Camera(
            captureTime: cameraTime.captureTime,
            device: device,
            modificationTime: cameraTime.modificationTime,
            orientation: orientation,
            subjectCoordinates: subjectCoordinates
        )
    }

    func parseLocation(from dictionary: NSDictionary) -> PhotoAssetMetadata.Location? {
        let gps = dictionary[kCGImagePropertyGPSDictionary] as? NSDictionary
        guard let latitude = gps?[kCGImagePropertyGPSLatitude] as? Double else {
            return nil
        }
        guard let longitude = gps?[kCGImagePropertyGPSLongitude] as? Double else {
            return nil
        }
        return PhotoAssetMetadata.Location(latitude: latitude, longitude: longitude)
    }

    func parseExif(from dictionary: NSDictionary) -> PhotoAsset.Exif {
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
