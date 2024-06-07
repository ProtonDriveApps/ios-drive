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

public struct NewPhotoBlocksParameters: Codable {
    let AddressID: String
    let ShareID: String
    let LinkID: String
    let RevisionID: String
    let BlockList: [Block]
    let ThumbnailList: [Thumbnail]

    public init(
        addressID: String,
        shareID: String,
        linkID: String,
        revisionID: String,
        blockList: [Block],
        thumbnailList: [Thumbnail]
    ) {
        self.AddressID = addressID
        self.ShareID = shareID
        self.LinkID = linkID
        self.RevisionID = revisionID
        self.BlockList = blockList
        self.ThumbnailList = thumbnailList
    }
    
    public struct Block: Codable {
        let Size: Int
        let Index: Int
        let EncSignature: String
        let Hash: String
        let Verifier: VerifierInfo

        struct VerifierInfo: Codable {
            let Token: String
        }
        
        public init(size: Int, index: Int, encSignature: String, hash: String, verificationToken: String) {
            self.Size = size
            self.Index = index
            self.EncSignature = encSignature
            self.Hash = hash
            self.Verifier = VerifierInfo(Token: verificationToken)
        }
    }
    
    public struct Thumbnail: Codable {
        let Size: Int
        let `Type`: Int
        let Hash: String
        
        public init(size: Int, type: Int, hash: String) {
            self.Size = size
            self.`Type` = type
            self.Hash = hash
        }
    }
}
