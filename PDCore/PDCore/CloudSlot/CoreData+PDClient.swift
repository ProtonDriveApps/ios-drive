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
import PDClient

public extension Volume {
    func fulfillVolume(with meta: PDClient.Volume) {
        self.maxSpace = meta.maxSpace ?? 0
        self.usedSpace = meta.usedSpace ?? 0
        let typeValue = Int16(meta.type.rawValue)
        self.type = PDCore.Volume.VolumeType(rawValue: typeValue) ?? .undetermined
    }
}

public extension Share {
    func fulfillShare(with meta: PDClient.Share) {
        self.flags = meta.flags
        self.creator = meta.creator

        self.addressID = meta.addressID
        self.key = meta.key
        self.passphrase = meta.passphrase
        self.passphraseSignature = meta.passphraseSignature
        self.type = ShareType(rawValue: Int16(meta.type.rawValue)) ?? .undefined
        self.volumeID = meta.volumeID
    }

    func fulfillShare(with meta: PDClient.ShareShort) {
        self.flags = meta.flags
        self.creator = meta.creator
        self.volumeID = meta.volumeID
    }
}

public extension Node {
    /// Use only from File.fulfillFile(with:) and Folder.fulfillFolder(with:), do not directly
    fileprivate func fulfillNode(with meta: PDClient.Link) {
        self.attributesMaskRaw = meta.attributes
        self.permissionsMaskRaw = meta.permissions
        self.name = meta.name
        self.nodeKey = meta.nodeKey
        self.nodePassphrase = meta.nodePassphrase
        self.nodePassphraseSignature = meta.nodePassphraseSignature
        self.signatureEmail = meta.signatureEmail
        self.nameSignatureEmail = meta.nameSignatureEmail
        self.nodeHash = meta.hash
        self.state = Node.State(meta.state)
        self.size = meta.size
        self.mimeType = meta.MIMEType
        self.createdDate = Date(timeIntervalSince1970: meta.createTime)
        self.modifiedDate = Date(timeIntervalSince1970: meta.modifyTime)
        self.isShared = meta.sharingDetails?.shareUrl != nil
        self.volumeID = meta.volumeID
    }
}

public extension File {
    func fulfillFile(with meta: PDClient.Link) {
        super.fulfillNode(with: meta)
        self.activeRevision?.xAttributes = meta.XAttr
        self.contentKeyPacket = meta.fileProperties?.contentKeyPacket
        self.contentKeyPacketSignature = meta.fileProperties?.contentKeyPacketSignature
    }

    func fulfillFile(with newFileDetails: NewFile) {
        self.id = newFileDetails.ID
    }
}

public extension Folder {
    func fulfillFolder(with meta: PDClient.Link) {
        super.fulfillNode(with: meta)
        self.nodeHashKey = meta.folderProperties?.nodeHashKey
    }
}

public extension Photo {
    func fulfillPhoto(with meta: PDClient.Link) {
        super.fulfillFile(with: meta)
        if let captureInterval = meta.fileProperties?.activeRevision?.photo?.captureTime {
            self.captureTime = Date(timeIntervalSince1970: captureInterval)
        }
        self.tags = meta.photoProperties?.tags
    }
}

public extension Revision {
    func fulfillRevision(with meta: PDClient.RevisionShort) {
        self.signatureAddress = meta.signatureAddress
        self.created = Date(timeIntervalSince1970: meta.createTime)
        self.id = meta.ID
        self.manifestSignature = meta.manifestSignature
        self.size = meta.size
        self.state = meta.state
    }

    func fulfillRevision(with meta: PDClient.Revision) {
        self.signatureAddress = meta.signatureAddress
        self.created = Date(timeIntervalSince1970: meta.createTime)
        self.id = meta.ID
        self.manifestSignature = meta.manifestSignature
        self.size = meta.size
        self.state = meta.state
        self.xAttributes = meta.XAttr
        if !(self is PhotoRevision),
           let hash = meta.thumbnailHash {
            // Old way of getting a thumbnail hash. Should be removed once we switch to new thumbnails listing in My Files.
            thumbnails.first?.sha256 = Data(base64Encoded: hash)
        }
    }
}

public extension PhotoRevision {
    func fulfillRevision(link: PDClient.Link, revision: PDClient.RevisionShort) {
        super.fulfillRevision(with: revision)
        self.exif = revision.photo?.exif ?? ""
        self.xAttributes = link.XAttr
        self.contentHash = revision.photo?.contentHash
    }
}

public extension DownloadBlock {
    func fulfillBlock(with meta: PDClient.Block) {
        self.index = meta.index
        self.sha256 = Data(base64Encoded: meta.hash).forceUnwrap()
        self.downloadUrl = meta.URL.absoluteString
        self.encSignature = meta.encSignature
        self.signatureEmail = meta.signatureEmail
    }
}

public extension ShareURL {
    func fulfillShareURL(with meta: ShareURLMeta) {
        self.token = meta.token
        self.id = meta.shareURLID
        self.expirationTime = meta.expirationTime.asDate
        self.lastAccessTime = meta.lastAccessTime.asDate
        self.maxAccesses = meta.maxAccesses
        self.numAccesses = meta.numAccesses
        self.name = meta.name
        self.creatorEmail = meta.creatorEmail
        self.permissions = meta.permissions
        self.createTime = Date(timeIntervalSince1970: meta.createTime)
        self.flags = meta.flags
        self.urlPasswordSalt = meta.urlPasswordSalt
        self.sharePasswordSalt = meta.sharePasswordSalt
        self.srpVerifier = meta.SRPVerifier
        self.srpModulusID = meta.SRPModulusID
        self.password = meta.password
        self.publicUrl = meta.publicUrl
        self.sharePassphraseKeyPacket = meta.sharePassphraseKeyPacket
    }

    func fulfillShareURL(with meta: ShareURLShortMeta) {
        self.id = meta.shareUrlID
        self.token = meta.token ?? ""
        self.expirationTime = meta.expireTime
        self.numAccesses = meta.numAccesses
        self.createTime = meta.createTime
    }
}

private extension Optional where Wrapped == TimeInterval {
    var asDate: Date? {
        guard let interval = self else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }
}

public extension CoreDataPhotoListing {
    func fulfillListing(with link: PDClient.Link) {
        // ids are already set
        self.addedTime = link.fileProperties?.activeRevision?.photo?.addedTime
        if let captureInterval = link.fileProperties?.activeRevision?.photo?.captureTime {
            self.captureTime = Date(timeIntervalSince1970: captureInterval)
        }
        self.contentHash = link.fileProperties?.activeRevision?.photo?.contentHash ?? ""
        self.nameHash = link.fileProperties?.activeRevision?.photo?.hash
        self.tagsRaw = CoreDataPhotoListing.tagsSerializer.serialize(tags: link.photoProperties?.tags ?? [])
    }
}

public extension CoreDataAlbum {
    func fulfillAlbum(with link: PDClient.Link) {
        super.fulfillNode(with: link)
        guard let albumProperties = link.albumProperties else {
            return
        }
        self.locked = albumProperties.locked
        self.coverLinkID = albumProperties.coverLinkID
        self.lastActivityTime = Date(timeIntervalSince1970: albumProperties.lastActivityTime)
        self.photoCount = Int16(albumProperties.photoCount)
        self.nodeHashKey = albumProperties.nodeHashKey
        self.xAttributes = link.XAttr
    }
}

public extension CoreDataAlbumListing {
    func fulfillAlbumListing(with link: PDClient.Link) {
        // id, volumeID are already set
        // TODO: `Albums` related - check that we actually need to store shareID directly
        self.shareID = link.sharingDetails?.shareID

        guard let albumProperties = link.albumProperties else {
            return
        }
        self.locked = albumProperties.locked
        self.coverLinkID = albumProperties.coverLinkID
        self.lastActivityTime = Date(timeIntervalSince1970: albumProperties.lastActivityTime)
        self.photoCount = Int16(albumProperties.photoCount)
    }
}
