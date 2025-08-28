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

public struct RevisionShort: Codable, Equatable {
    public var ID: Revision.RevisionID
    public var createTime: TimeInterval
    public var size: Int
    public var manifestSignature: String? // can be nil if revision is a draft
    public var signatureAddress: String
    public var state: NodeState
    public var thumbnailDownloadUrl: URL?
    private var thumbnail: Int
    public var thumbnails: [Thumbnail]?
    public var photo: Photo?

    public var hasThumbnail: Bool {
        NSNumber.init(value: thumbnail).boolValue
    }

    public init(ID: Revision.RevisionID, createTime: TimeInterval, size: Int, manifestSignature: String, signatureAddress: String, state: NodeState, thumbnailDownloadUrl: URL? = nil, thumbnail: Int, thumbnails: [Thumbnail]? = nil, photo: Photo? = nil) {
        self.ID = ID
        self.createTime = createTime
        self.size = size
        self.manifestSignature = manifestSignature
        self.signatureAddress = signatureAddress
        self.state = state
        self.thumbnailDownloadUrl = thumbnailDownloadUrl
        self.thumbnail = thumbnail
        self.thumbnails = thumbnails
        self.photo = photo
    }
    
}

public struct Revision: Codable {
    public typealias RevisionID = String

    public var ID: RevisionID
    public var createTime: TimeInterval
    public var size: Int
    public var manifestSignature: String
    public var signatureAddress: String
    public var state: NodeState
    public var blocks: [Block]
    public var thumbnail: Int
    public var thumbnailHash: String?
    public var thumbnailDownloadUrl: URL?
    public var XAttr: String?

    public init(ID: RevisionID, 
                createTime: TimeInterval,
                size: Int,
                manifestSignature: String,
                signatureAddress: String,
                state: NodeState, 
                blocks: [Block],
                thumbnail: Int,
                thumbnailHash: String?,
                thumbnailDownloadUrl: URL?,
                XAttr: String?) {
        self.ID = ID
        self.createTime = createTime
        self.size = size
        self.manifestSignature = manifestSignature
        self.signatureAddress = signatureAddress
        self.state = state
        self.blocks = blocks
        self.thumbnail = thumbnail
        self.thumbnailHash = thumbnailHash
        self.thumbnailDownloadUrl = thumbnailDownloadUrl
        self.XAttr = XAttr
    }
}

public struct Block: Codable {
    public var index: Int
    public var hash: String
    public var URL: URL
    public var encSignature: String?
    public var signatureEmail: String?
}

public struct Thumbnail: Codable, Equatable {
    public var thumbnailID: String
    public var type: Int
    public var hash: String
    public var size: Int

    public init(thumbnailID: String, type: Int, hash: String, size: Int) {
        self.thumbnailID = thumbnailID
        self.type = type
        self.hash = hash
        self.size = size
    }
}

public struct Photo: Codable, Equatable {
    public var linkID: String
    public var captureTime: TimeInterval
    public var addedTime: Date?
    public var mainPhotoLinkID: String?
    public var relatedPhotosLinkIDs: [String]?
    public var hash: String // name hash
    public var contentHash: String? // optional due to backward compatibility of events
    public var exif: String?
}
