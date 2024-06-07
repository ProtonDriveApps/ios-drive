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

public struct PhotoMetadata: Equatable, Codable {

    public let ios: iOSMeta?

    public struct iOSMeta: Equatable, Codable {
        public let cloudIdentifier: String
        public let modifiedDate: Date?

        public init(cloudIdentifier: String, modifiedDate: Date?) {
            self.cloudIdentifier = cloudIdentifier
            self.modifiedDate = modifiedDate
        }
    }
}

extension PhotoMetadata {
    init(_ metadata: PhotoAssetMetadata) {
        self.ios = iOSMeta(cloudIdentifier: metadata.iOSPhotos.identifier, modifiedDate: metadata.iOSPhotos.modificationTime)
    }

    static var blank: PhotoMetadata { PhotoMetadata(ios: nil) }
}
