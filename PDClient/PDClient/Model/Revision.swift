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

public struct RevisionShort: Codable {
    public let ID: Revision.RevisionID
    public let createTime: TimeInterval
    public let size: Int
    public let manifestSignature: String
    public let signatureAddress: String
    public let state: NodeState
    public let thumbnailDownloadUrl: URL?
    private  let thumbnail: Int

    public var hasThumbnail: Bool {
        NSNumber.init(value: thumbnail).boolValue
    }

}

public struct Revision: Codable {
    public typealias RevisionID = String

    public let ID: RevisionID
    public let createTime: TimeInterval
    public let size: Int
    public let manifestSignature: String
    public let signatureAddress: String
    public let state: NodeState
    public let blocks: [Block]
    public let thumbnail: Int
    public let thumbnailHash: String?
    public let thumbnailDownloadUrl: URL?
    public let XAttr: String?
}

public struct Block: Codable {
    public let index: Int
    public let hash: String
    public let URL: URL
    public let encSignature: String
    public let signatureEmail: String?
}
