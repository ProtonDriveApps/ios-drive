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

public struct ShareShort: Codable {
    public var shareID: Share.ShareID
    public var volumeID: Volume.VolumeID
    
    public var flags: Share.Flags
    
    public var linkID: Link.LinkID
    public var creator: String
    
    public init(shareID: Share.ShareID,
                volumeID: Volume.VolumeID,
                flags: Share.Flags,
                linkID: Link.LinkID, creator: String) {
        self.shareID = shareID
        self.volumeID = volumeID
        self.flags = flags
        self.linkID = linkID
        self.creator = creator
    }
}

public struct Share: Codable {
    public typealias ShareID = String
    
    public struct Flags: OptionSet, Codable {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        public static let main = Flags(rawValue: 1 << 0)
    }

    public var flags: Flags
    public var shareID: ShareID
    public var volumeID: Volume.VolumeID
    public var linkID: Link.LinkID
    public var creator, addressID: String
    public var key, passphrase, passphraseSignature: String
    public let type: ´Type´

    public enum ´Type´: Int, Codable {
        case main = 1
        case standard = 2
        case device = 3
        case photos = 4
    }
    
    public init(flags: Flags, shareID: ShareID, volumeID: Volume.VolumeID, linkID: Link.LinkID,
                creator: String, addressID: String, key: String, 
                passphrase: String, passphraseSignature: String, type: ´Type´) {
        self.flags = flags
        self.shareID = shareID
        self.volumeID = volumeID
        self.linkID = linkID
        self.creator = creator
        self.addressID = addressID
        self.key = key
        self.passphrase = passphrase
        self.passphraseSignature = passphraseSignature
        self.type = type
    }
}

public extension ShareShort {
    init(from share: Share) {
        self.shareID = share.shareID
        self.volumeID = share.volumeID
        self.flags = share.flags
        self.linkID = share.linkID
        self.creator = share.creator
    }
}
