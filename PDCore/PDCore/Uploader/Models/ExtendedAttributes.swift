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

public class ExtendedAttributes: NSObject, Codable {
    public let common: Common?
    public let location: Location?
    public let camera: Camera?
    public let media: Media?
    public let iOSPhotos: iOSPhotos?
    
    public init(common: ExtendedAttributes.Common? = nil, location: ExtendedAttributes.Location? = nil, camera: ExtendedAttributes.Camera? = nil, media: ExtendedAttributes.Media? = nil, iOSPhotos: ExtendedAttributes.iOSPhotos? = nil) {
        self.common = common
        self.location = location
        self.camera = camera
        self.media = media
        self.iOSPhotos = iOSPhotos
    }

    enum CodingKeys: String, CodingKey {
        case common = "Common"
        case location = "Location"
        case camera = "Camera"
        case media = "Media"
        case iOSPhotos = "iOS.photos"
    }
    
    public struct Common: Codable {
        public let modificationTime: String?
        public let size: Int?
        public let blockSizes: [Int]?
        public let digests: Digests?

        enum CodingKeys: String, CodingKey {
            case modificationTime = "ModificationTime"
            case size = "Size"
            case blockSizes = "BlockSizes"
            case digests = "Digests"
        }
    }
    
    public struct Digests: Codable {
        public let sha1: String?
        
        enum CodingKeys: String, CodingKey {
            case sha1 = "SHA1"
        }
    }

    public struct Location: Codable {
        public let latitude: Double
        public let longitude: Double

        enum CodingKeys: String, CodingKey {
            case latitude = "Latitude"
            case longitude = "Longitude"
        }
    }
    
    public struct Camera: Codable {
        public let captureTime: String?
        public let device: String?
        public let orientation: Int?
        public let subjectCoordinates: SubjectCoordinates?

        enum CodingKeys: String, CodingKey {
            case captureTime = "CaptureTime"
            case device = "Device"
            case orientation = "Orientation"
            case subjectCoordinates = "SubjectCoordinates"
        }
    }

    public struct SubjectCoordinates: Codable {
        public let top: Int
        public let left: Int
        public let bottom: Int
        public let right: Int

        enum CodingKeys: String, CodingKey {
            case top = "Top"
            case left = "Left"
            case bottom = "Bottom"
            case right = "Right"
        }
    }
    
    public struct Media: Codable {
        public let width: Int?
        public let height: Int?
        public let duration: Double?

        enum CodingKeys: String, CodingKey {
            case width = "Width"
            case height = "Height"
            case duration = "Duration"
        }
    }
    
    public struct iOSPhotos: Codable {
        public let iCloudID: String?
        public let modificationTime: String?
        
        enum CodingKeys: String, CodingKey {
            case iCloudID = "ICloudID"
            case modificationTime = "ModificationTime"
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
