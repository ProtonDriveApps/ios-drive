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

struct ShareShortWithoutLinkType: Codable {
    public var blockSize: Int
    public var permissionsMask: Share.PermissionMask
    public var shareID: Share.ShareID
    public var volumeID: Volume.VolumeID
    
    public var flags: Share.Flags
    
    public var linkID: Link.LinkID
    public var creator: String
}

public struct ShareShort: Codable {
    public var blockSize: Int
    public var permissionsMask: Share.PermissionMask
    public var shareID: Share.ShareID
    public var volumeID: Volume.VolumeID
    
    public var flags: Share.Flags
    
    public var linkID: Link.LinkID
    public var linkType: LinkType
    public var creator: String
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
    public var blockSize: Int
    public var permissionsMask: PermissionMask
    public var shareID: ShareID
    public var volumeID: Volume.VolumeID
    public var linkID: Link.LinkID
    public var linkType: LinkType
    public var creator, addressID: String
    public var key, passphrase, passphraseSignature: String
    
    public struct PermissionMask: OptionSet, Codable {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        public static let full = PermissionMask([])
    }
}

public extension ShareShort {
    init(from share: Share) {
        self.blockSize = share.blockSize
        self.permissionsMask = share.permissionsMask
        self.shareID = share.shareID
        self.volumeID = share.volumeID
        self.flags = share.flags
        self.linkID = share.linkID
        self.linkType = share.linkType
        self.creator = share.creator
    }
}

extension ShareShort {
    init(from share: ShareShortWithoutLinkType) {
        self.blockSize = share.blockSize
        self.permissionsMask = share.permissionsMask
        self.shareID = share.shareID
        self.volumeID = share.volumeID
        self.flags = share.flags
        self.linkID = share.linkID
        self.linkType = .folder
        self.creator = share.creator
    }
}
