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
    public let contentHash: String
    public let exif: Exif
    public let metadata: Metadata

    public init(url: URL, filename: String, contentHash: String, exif: PhotoAsset.Exif, metadata: PhotoAsset.Metadata) {
        self.url = url
        self.filename = filename
        self.contentHash = contentHash
        self.exif = exif
        self.metadata = metadata
    }

    public typealias Exif = Data

    public struct Metadata: Equatable {

        public let cloudIdentifier: String
        public let creationDate: Date?
        public let modifiedDate: Date?
        public let width: Int
        public let height: Int
        public let duration: Double?

        public init(cloudIdentifier: String, creationDate: Date? = nil, modifiedDate: Date? = nil, width: Int, height: Int, duration: Double?) {
            self.cloudIdentifier = cloudIdentifier
            self.creationDate = creationDate
            self.modifiedDate = modifiedDate
            self.width = width
            self.height = height
            self.duration = duration
        }

    }

}
