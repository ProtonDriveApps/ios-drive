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

public struct Link: Codable, Equatable {
    public typealias LinkID = String
    
    #if os(iOS)
    public var volumeID: String
    #else
    // this must be removed once macOS implements the migration to volumeID-based DB
    public var volumeID: String { "" }
    #endif
    // node
    public var linkID: LinkID
    public var parentLinkID: LinkID?
    public var type: LinkType
    public var name: String
    public var nameSignatureEmail: String?
    public var hash: String
    public var state: NodeState
    public var expirationTime: TimeInterval?
    public var size: Int
    public var MIMEType: String
    public var attributes: AttriburesMask
    public var permissions: PermissionMask
    public var nodeKey: String
    public var nodePassphrase: String
    public var nodePassphraseSignature: String
    public var signatureEmail: String
    public var createTime: TimeInterval
    public var modifyTime: TimeInterval
    public var trashed: TimeInterval?
    public var sharingDetails: SharingDetails?
    public var nbUrls: Int
    public var activeUrls: Int
    public var urlsExpired: Int
    public var XAttr: String?
    public var fileProperties: FileProperties?
    public var folderProperties: FolderProperties?
    public var documentProperties: DocumentProperties?
    public var photoProperties: PhotoProperties?
    public var albumProperties: AlbumProperties?

    public init(linkID: LinkID, parentLinkID: LinkID?, volumeID: String, type: LinkType, name: String,
                nameSignatureEmail: String?, hash: String, state: NodeState, expirationTime: TimeInterval?,
                size: Int, MIMEType: String, attributes: AttriburesMask, permissions: PermissionMask,
                nodeKey: String, nodePassphrase: String, nodePassphraseSignature: String,
                signatureEmail: String, createTime: TimeInterval, modifyTime: TimeInterval,
                trashed: TimeInterval?, sharingDetails: SharingDetails?, nbUrls: Int, activeUrls: Int,
                urlsExpired: Int, XAttr: String?, fileProperties: FileProperties?, folderProperties: FolderProperties?,
                documentProperties: DocumentProperties? = nil, photoProperties: PhotoProperties? = nil,
                albumProperties: AlbumProperties? = nil) {
        self.linkID = linkID
        self.parentLinkID = parentLinkID
        #if os(iOS)
        self.volumeID = volumeID
        #endif
        self.type = type
        self.name = name
        self.nameSignatureEmail = nameSignatureEmail
        self.hash = hash
        self.state = state
        self.expirationTime = expirationTime
        self.size = size
        self.MIMEType = MIMEType
        self.attributes = attributes
        self.permissions = permissions
        self.nodeKey = nodeKey
        self.nodePassphrase = nodePassphrase
        self.nodePassphraseSignature = nodePassphraseSignature
        self.signatureEmail = signatureEmail
        self.createTime = createTime
        self.modifyTime = modifyTime
        self.trashed = trashed
        self.sharingDetails = sharingDetails
        self.nbUrls = nbUrls
        self.activeUrls = activeUrls
        self.urlsExpired = urlsExpired
        self.XAttr = XAttr
        self.fileProperties = fileProperties
        self.folderProperties = folderProperties
        self.documentProperties = documentProperties
        self.photoProperties = photoProperties
        self.albumProperties = albumProperties
    }

    // Convenience initializer to allow migration to volume based APIs
    public init(link: Link, volumeID: String) {
        self.linkID = link.linkID
        self.parentLinkID = link.parentLinkID
        #if os(iOS)
        self.volumeID = volumeID
        #endif
        self.type = link.type
        self.name = link.name
        self.nameSignatureEmail = link.nameSignatureEmail
        self.hash = link.hash
        self.state = link.state
        self.expirationTime = link.expirationTime
        self.size = link.size
        self.MIMEType = link.MIMEType
        self.attributes = link.attributes
        self.permissions = link.permissions
        self.nodeKey = link.nodeKey
        self.nodePassphrase = link.nodePassphrase
        self.nodePassphraseSignature = link.nodePassphraseSignature
        self.signatureEmail = link.signatureEmail
        self.createTime = link.createTime
        self.modifyTime = link.modifyTime
        self.trashed = link.trashed
        self.sharingDetails = link.sharingDetails
        self.nbUrls = link.nbUrls
        self.activeUrls = link.activeUrls
        self.urlsExpired = link.urlsExpired
        self.XAttr = link.XAttr
        self.fileProperties = link.fileProperties
        self.folderProperties = link.folderProperties
        self.documentProperties = link.documentProperties
        self.photoProperties = link.photoProperties
        self.albumProperties = link.albumProperties
    }
}

public extension Link {
    static func emptyDeletedLink(id: Link.LinkID) -> Link {
        Link(
            linkID: id,
            parentLinkID: nil,
            volumeID: "",
            type: .file,
            name: "",
            nameSignatureEmail: "",
            hash: "",
            state: .deleted,
            expirationTime: .zero,
            size: 0,
            MIMEType: "",
            attributes: 0,
            permissions: 0,
            nodeKey: "",
            nodePassphrase: "",
            nodePassphraseSignature: "",
            signatureEmail: "",
            createTime: 0,
            modifyTime: 0,
            trashed: .zero,
            sharingDetails: nil,
            nbUrls: 0,
            activeUrls: 0,
            urlsExpired: 0,
            XAttr: nil,
            fileProperties: nil,
            folderProperties: nil,
            documentProperties: nil
        )
    }
}

public enum LinkType: Int, Codable, CaseIterable, Equatable {
    case folder = 1
    case file = 2
    case album = 3

    public var desc: String {
        switch self {
        case .folder: "Folder"
        case .file: "File"
        case .album: "Album"
        }
    }
}

public enum NodeState: Int, Codable, Equatable {
    case draft = 0
    case active = 1
    case deleted = 2
    case deleting = 3
    
    public init?(rawValue: Int) {
        switch rawValue {
        case Self.draft.rawValue: self = .draft
        case Self.active.rawValue: self = .active
        case Self.deleted.rawValue: self = .deleted
        case Self.deleting.rawValue: self = .deleting
        default: return nil
        }
    }
}

public struct FileProperties: Codable, Equatable {
    public var contentKeyPacket: String
    public var contentKeyPacketSignature: String?
    public var activeRevision: RevisionShort?

    public init(contentKeyPacket: String, contentKeyPacketSignature: String?, activeRevision: RevisionShort?) {
        self.contentKeyPacket = contentKeyPacket
        self.contentKeyPacketSignature = contentKeyPacketSignature
        self.activeRevision = activeRevision
    }
}

public struct FolderProperties: Codable, Equatable {
    public var nodeHashKey: String

    public init(nodeHashKey: String) {
        self.nodeHashKey = nodeHashKey
    }
}

public struct DocumentProperties: Codable, Equatable {
    public var size: Int
}

public struct PhotoProperties: Codable, Equatable {
    public var albums: [PhotoAlbum]
    // Could become nonoptional, but migration of `PersistedEvent`, relying on `Link`'s structure would be needed.
    public var tags: [Int]?
}

public struct PhotoAlbum: Codable, Equatable {
    public var albumLinkID: String
}

public struct AlbumProperties: Codable, Equatable {
    public var locked: Bool
    public var coverLinkID: String? // Nullable
    public var lastActivityTime: TimeInterval // last time a Photo was added to the Album
    public var nodeHashKey: String
    public var photoCount: Int
}

public struct SharingDetails: Codable, Equatable {
    public var shareID: String
    public var shareUrl: ShareURL? // can be null if no link is available

    public init(shareID: String, shareUrl: ShareURL?) {
        self.shareID = shareID
        self.shareUrl = shareUrl
    }
}

public struct ShareURL: Codable, Equatable {
    public var shareUrlID: String
    public var token: String? // not always provided, according to docs
    public var expireTime: Date?
    public var createTime: Date
    public var numAccesses: Int
    public var shareID: String
}

public typealias ShareURLShortMeta = ShareURL
