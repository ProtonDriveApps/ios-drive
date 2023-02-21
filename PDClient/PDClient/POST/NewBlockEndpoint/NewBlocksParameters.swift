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

public struct NewBlockMeta: Codable {
    let Hash: String
    let EncSignature: String
    let SignatureEmail: String
    let Size: Int
    let Index: Int

    public init(hash: String, encryptedSignature: String, signatureEmail: String, size: Int, index: Int) {
        self.Hash = hash
        self.EncSignature = encryptedSignature
        self.SignatureEmail = signatureEmail
        self.Size = size
        self.Index = index
    }
}

public struct NewThumbnailMeta: Codable {
    let size: Int
    let hash: String

    public init(size: Int, hash: String) {
        self.hash = hash
        self.size = size
    }
}

public struct NewBlocksParameters: Codable {
    let BlockList: [NewBlockMeta]
    let AddressID: String
    let ShareID: String
    let LinkID: String
    let RevisionID: String
    let Thumbnail: Int?
    let ThumbnailHash: String?
    let ThumbnailSize: Int?

    public init(
        blockList: [NewBlockMeta],
        thumbnail: NewThumbnailMeta? = nil,
        addressID: String,
        shareID: String,
        linkID: String,
        revisionID: String) {
        self.BlockList = blockList
        self.AddressID = addressID
        self.ShareID = shareID
        self.LinkID = linkID
        self.RevisionID = revisionID

        if let thumbnail = thumbnail {
            self.Thumbnail = 1
            self.ThumbnailHash = thumbnail.hash
            self.ThumbnailSize = thumbnail.size
        } else {
            self.Thumbnail = nil
            self.ThumbnailHash = nil
            self.ThumbnailSize = nil
        }
    }
}
