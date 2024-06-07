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

public struct PhotoAsset: Equatable {

    public let url: URL
    public let filename: String
    public let mimeType: MimeType
    public let exif: Exif
    public let metadata: PhotoAssetMetadata

    public init(url: URL, filename: String, mimeType: MimeType, exif: PhotoAsset.Exif, metadata: PhotoAssetMetadata) {
        self.url = url
        self.filename = filename
        self.mimeType = mimeType
        self.exif = exif
        self.metadata = metadata
    }

    public typealias Exif = Data
}

public struct PhotoAssetMetadata: Equatable {
    public struct Media: Equatable {
        public let width: Int
        public let height: Int
        public let duration: Double?

        public init(width: Int, height: Int, duration: Double?) {
            self.width = width
            self.height = height
            self.duration = duration
        }
    }

    public struct Location: Equatable {
        public let latitude: Double
        public let longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public struct Camera: Equatable {
        public let captureTime: Date?
        public let device: String?
        public let modificationTime: Date?
        public let orientation: Int?
        public let subjectCoordinates: SubjectCoordinates?

        public init(
            captureTime: Date?,
            device: String?,
            modificationTime: Date? = nil,
            orientation: Int?,
            subjectCoordinates: SubjectCoordinates?
        ) {
            self.captureTime = captureTime
            self.device = device
            self.modificationTime = modificationTime
            self.orientation = orientation
            self.subjectCoordinates = subjectCoordinates
        }
    }

    public struct SubjectCoordinates: Equatable {
        public let top: Int
        public let left: Int
        public let bottom: Int
        public let right: Int

        public init(top: Int, left: Int, bottom: Int, right: Int) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }
    }

    public struct iOSPhotos: Equatable, Hashable {
        public let identifier: String
        public let modificationTime: Date?

        public init(identifier: String, modificationTime: Date?) {
            self.identifier = identifier
            self.modificationTime = modificationTime
        }
    }

    public let media: Media
    public let camera: Camera
    public let location: Location?
    public let iOSPhotos: iOSPhotos

    public init(media: Media, camera: Camera, location: Location?, iOSPhotos: iOSPhotos) {
        self.media = media
        self.camera = camera
        self.location = location
        self.iOSPhotos = iOSPhotos
    }
}
