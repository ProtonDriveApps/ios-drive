// Copyright (c) 2024 Proton AG
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

// Used before volume-centric model was introduced (addition of `volumeId` to `Link`)
// Needs to be used for decoding persisted events that are to be converted to the new `Link`.
public struct LegacyEvent: Codable {
    public var contextShareID: Share.ShareID
    public var eventID: EventID
    public var eventType: EventType
    public var createTime: TimeInterval
    public var link: LegacyLink

    enum CodingKeys: String, CodingKey {
        case eventID
        case eventType
        case createTime
        case link
        case contextShareID
    }

    private struct MinimalLink: Codable {
        public var linkID: String
    }

    // MARK: - Decodable

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.eventID = try values.decode(EventID.self, forKey: .eventID)
        self.eventType = try values.decode(EventType.self, forKey: .eventType)
        self.createTime = try values.decode(TimeInterval.self, forKey: .createTime)

        // contextShareID is allowed to be missing in .delete events, but others should have it
        do {
            self.contextShareID = try values.decode(Share.ShareID.self, forKey: .contextShareID)
        } catch where eventType == .delete {
            self.contextShareID = ""
        }

        do {
            // .update and .create events come with a full link inside
            self.link = try values.decode(LegacyLink.self, forKey: .link)
        } catch _ where self.eventType == .delete {
            // delete events come with only LinkID inside
            let linkID = try values.decode(MinimalLink.self, forKey: .link).linkID

            // so we create an empty Link object to obscure this fact from higher layers of the app
            self.link = LegacyLink.emptyDeletedLink(id: linkID)
        } catch let error {
            // if that did not help as well - throw encoding error
            assert(false, error.localizedDescription)
            throw error
        }
    }
}

// Needs to be used for decoding persisted links that are to be converted to the new `Link`.
public struct LegacyLink: Codable {
    public typealias LinkID = String

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

    public init(linkID: LinkID, parentLinkID: LinkID?, type: LinkType, name: String,
                nameSignatureEmail: String?, hash: String, state: NodeState, expirationTime: TimeInterval?,
                size: Int, MIMEType: String, attributes: AttriburesMask, permissions: PermissionMask,
                nodeKey: String, nodePassphrase: String, nodePassphraseSignature: String,
                signatureEmail: String, createTime: TimeInterval, modifyTime: TimeInterval,
                trashed: TimeInterval?, sharingDetails: SharingDetails?, nbUrls: Int, activeUrls: Int,
                urlsExpired: Int, XAttr: String?, fileProperties: FileProperties?, folderProperties: FolderProperties?, documentProperties: DocumentProperties?) {
        self.linkID = linkID
        self.parentLinkID = parentLinkID
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
   
    static func emptyDeletedLink(id: Link.LinkID) -> LegacyLink {
        LegacyLink(
            linkID: id,
            parentLinkID: nil,
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

// MARK: - Mapping to new Event & Link versions

extension LegacyEvent {
    public func mapToEvent() -> Event {
        Event(
            contextShareID: contextShareID,
            eventID: eventID,
            eventType: eventType,
            createTime: createTime,
            link: link.mapToLink(),
            data: nil
        )
    }
}

extension LegacyLink {
    func mapToLink() -> Link {
        Link(
            linkID: linkID,
            parentLinkID: parentLinkID,
            volumeID: "", // Persisted links don't have volumeID
            type: type,
            name: name,
            nameSignatureEmail: nameSignatureEmail,
            hash: hash,
            state: state,
            expirationTime: expirationTime,
            size: size,
            MIMEType: MIMEType,
            attributes: attributes,
            permissions: permissions,
            nodeKey: nodeKey,
            nodePassphrase: nodePassphrase,
            nodePassphraseSignature: nodePassphraseSignature,
            signatureEmail: signatureEmail,
            createTime: createTime,
            modifyTime: modifyTime,
            trashed: trashed,
            sharingDetails: sharingDetails,
            nbUrls: nbUrls,
            activeUrls: activeUrls,
            urlsExpired: urlsExpired,
            XAttr: XAttr,
            fileProperties: fileProperties,
            folderProperties: folderProperties
        )
    }
}
