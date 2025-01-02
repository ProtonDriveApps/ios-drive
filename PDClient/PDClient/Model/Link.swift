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

public struct Link: Codable {
    public typealias LinkID = String
    
    #if os(iOS)
    public let volumeID: String
    #else
    // this must be removed once macOS implements the migration to volumeID-based DB
    public var volumeID: String { "" }
    #endif
    // node
    public let linkID: LinkID
    public let parentLinkID: LinkID?
    public let type: LinkType
    public let name: String
    public let nameSignatureEmail: String?
    public let hash: String
    public let state: NodeState
    public let expirationTime: TimeInterval?
    public let size: Int
    public let MIMEType: String
    public let attributes: AttriburesMask
    public let permissions: PermissionMask
    public let nodeKey: String
    public let nodePassphrase: String
    public let nodePassphraseSignature: String
    public let signatureEmail: String
    public let createTime: TimeInterval
    public let modifyTime: TimeInterval
    public let trashed: TimeInterval?
    public let sharingDetails: SharingDetails?
    public let nbUrls: Int
    public let activeUrls: Int
    public let urlsExpired: Int
    public let XAttr: String?
    public let fileProperties: FileProperties?
    public let folderProperties: FolderProperties?
    public let documentProperties: DocumentProperties?

    public init(linkID: LinkID, parentLinkID: LinkID?, volumeID: String, type: LinkType, name: String,
                nameSignatureEmail: String?, hash: String, state: NodeState, expirationTime: TimeInterval?,
                size: Int, MIMEType: String, attributes: AttriburesMask, permissions: PermissionMask,
                nodeKey: String, nodePassphrase: String, nodePassphraseSignature: String,
                signatureEmail: String, createTime: TimeInterval, modifyTime: TimeInterval,
                trashed: TimeInterval?, sharingDetails: SharingDetails?, nbUrls: Int, activeUrls: Int,
                urlsExpired: Int, XAttr: String?, fileProperties: FileProperties?, folderProperties: FolderProperties?, documentProperties: DocumentProperties? = nil) {
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

public enum LinkType: Int, Codable {
    case folder = 1
    case file = 2
}

public enum NodeState: Int, Codable {
    case draft = 0
    case active = 1
    case deleted = 2
    case deleting = 3
    
    @available(*, deprecated, message: "This covers BE bug, fixed by Slim-API MR/15034")
    case errorState = 100 // error
    
    public init?(rawValue: Int) {
        switch rawValue {
        case Self.draft.rawValue: self = .draft
        case Self.active.rawValue: self = .active
        case Self.deleted.rawValue: self = .deleted
        case Self.deleting.rawValue: self = .deleting
        default: self = .errorState // BE returns enexpected value
        }
    }
}

public struct FileProperties: Codable {
    public let contentKeyPacket: String
    public let contentKeyPacketSignature: String?
    public let activeRevision: RevisionShort?

    public init(contentKeyPacket: String, contentKeyPacketSignature: String?, activeRevision: RevisionShort?) {
        self.contentKeyPacket = contentKeyPacket
        self.contentKeyPacketSignature = contentKeyPacketSignature
        self.activeRevision = activeRevision
    }
}

public struct FolderProperties: Codable {
    public var nodeHashKey: String
}

public struct DocumentProperties: Codable {
    public var size: Int
}

public struct SharingDetails: Codable {
    public let shareID: String
    public let shareUrl: ShareURL? // can be null if no link is available
    
    public init(shareID: String, shareUrl: ShareURL?) {
        self.shareID = shareID
        self.shareUrl = shareUrl
    }
}

public struct ShareURL: Codable {
    public let shareUrlID: String
    public let token: String? // not always provided, according to docs
    public let expireTime: Date?
    public let createTime: Date
    public let numAccesses: Int
    public let shareID: String
}

public typealias ShareURLShortMeta = ShareURL
