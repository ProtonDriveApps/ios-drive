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

public struct ExtendedAttributes: Codable {
    public let common: Common?

    public init(common: Common) {
        self.common = common
    }

    public struct Common: Codable {
        public let modificationTime: String?
        public let size: Int?
        public let blockSizes: [Int]?
        public let digests: Digests?

        public init(modificationTime: Date, size: Int, blockSizes: [Int], digests: Digests?) {
            self.modificationTime = ISO8601DateFormatter().string(from: modificationTime)
            self.size = size
            self.blockSizes = blockSizes
            self.digests = digests
        }

        enum CodingKeys: String, CodingKey {
            case modificationTime = "ModificationTime"
            case size = "Size"
            case blockSizes = "BlockSizes"
            case digests = "Digests"
        }
    }
    
    public struct Digests: Codable {
        public let sha1: String?
        
        public init(sha1: String?) {
            self.sha1 = sha1
        }
        
        enum CodingKeys: String, CodingKey {
            case sha1 = "SHA1"
        }
    }

    enum CodingKeys: String, CodingKey {
        case common = "Common"
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
