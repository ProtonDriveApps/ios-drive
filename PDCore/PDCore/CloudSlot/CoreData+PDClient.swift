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
    func fulfill(from meta: PDClient.Volume) {
        self.maxSpace = meta.maxSpace ?? 0
        self.usedSpace = meta.usedSpace ?? 0
    }
}

public extension Share {
    func fulfill(from meta: PDClient.Share) {
        self.flags = meta.flags
        self.creator = meta.creator
        
        self.addressID = meta.addressID
        self.key = meta.key
        self.passphrase = meta.passphrase
        self.passphraseSignature = meta.passphraseSignature
        self.type = ShareType(rawValue: Int16(meta.type.rawValue)) ?? .undefined
    }
    func fulfill(from meta: PDClient.ShareShort) {
        self.flags = meta.flags
        self.creator = meta.creator
    }
}

public extension Node {
    /// Use only from File.fulfill(from:) and Folder.fulfill(from:), do not directly
    fileprivate func fulfillBase(from meta: PDClient.Link) {
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
        self.isShared = meta.sharingDetails != nil
    }
}
public extension File {
    func fulfill(from meta: PDClient.Link) {
        super.fulfillBase(from: meta)
        self.activeRevision?.xAttributes = meta.XAttr
        self.contentKeyPacket = meta.fileProperties?.contentKeyPacket
        self.contentKeyPacketSignature = meta.fileProperties?.contentKeyPacketSignature
    }
    
    func fulfill(from newFileDetails: NewFile) {
        self.id = newFileDetails.ID
    }
}

public extension Folder {
    func fulfill(from meta: PDClient.Link) {
        super.fulfillBase(from: meta)
        self.nodeHashKey = meta.folderProperties?.nodeHashKey
    }
    func fulfill(from newFolderDetails: NewFolder) {
        self.id = newFolderDetails.ID
    }
}

public extension Photo {
    func fulfillPhoto(from meta: PDClient.Link) {
        super.fulfill(from: meta)
        if let captureInterval = meta.fileProperties?.activeRevision?.photo?.captureTime {
            self.captureTime = Date(timeIntervalSince1970: captureInterval)
        }
    }
}

public extension Revision {
    func fulfill(from meta: PDClient.RevisionShort) {
        self.signatureAddress = meta.signatureAddress
        self.created = Date(timeIntervalSince1970: meta.createTime)
        self.id = meta.ID
        self.manifestSignature = meta.manifestSignature
        self.size = meta.size
        self.state = meta.state
    }
    
    func fulfill(from meta: PDClient.Revision) {
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
    func fulfill(link: PDClient.Link, revision: PDClient.RevisionShort) {
        super.fulfill(from: revision)
        self.exif = revision.photo?.exif ?? ""
        self.xAttributes = link.XAttr
    }
}

public extension DownloadBlock {
    func fulfill(from meta: PDClient.Block) {
        self.index = meta.index
        self.sha256 = Data(base64Encoded: meta.hash).forceUnwrap()
        self.downloadUrl = meta.URL.absoluteString
        self.encSignature = meta.encSignature
        self.signatureEmail = meta.signatureEmail
    }
}

public extension ShareURL {
    func fulfill(from meta: ShareURLMeta) {
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
}

private extension Optional where Wrapped == TimeInterval {
    var asDate: Date? {
        guard let interval = self else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }
}
