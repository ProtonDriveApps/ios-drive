// Copyright (c) 2026 Proton AG
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
import ProtonCoreNetworking
import ProtonDriveSDK
@preconcurrency import PDClient
@preconcurrency import PDCore
import ProtonCoreUtilities
import CoreData

extension MetadataUpdater {
    
    // MARK: Common

    private func getSharingDetails(from response: JSONDictionary, context: String) -> SharingDetails? {
        if let sharingDetails: SharingDetails = try? obtainOptional("SharingDetails", from: response, context: "\(context).SharingDetails") {
            // Only present in v1 calls
            return sharingDetails
        } else if let sharing: JSONDictionary = try? obtainOptional("Sharing", from: response, context: "\(context).Sharing"),
                  let shareId: String = try? obtain("ShareID", from: sharing, context: "\(context).Sharing.ShareID") {
            // Trying to map v2 sharing to legacy structure. Multiple of the attributes are not ever used, so we can use empty / placeholders
            let shareURLID: String? = try? obtainOptional("ShareURLID", from: sharing, context: "\(context).Sharing.ShareID")
            return SharingDetails(shareID: shareId, shareUrl: shareURLID.map { ShareURL(shareUrlID: $0, createTime: Date(), numAccesses: 0, shareID: shareId) })
        } else {
            return nil
        }
    }
    
    // MARK: Photo
    
    func parsePhotoRevisionShort(
        from activeRevision: JSONDictionary,
        nodeState: Int,
        linkID: String,
        nameHash: String,
        photoDTO: JSONDictionary?
    ) throws -> RevisionShort {
        let revisionContext = "loadPhotoLinkDetailCall.responseBody.dataDTO.ActiveRevision"
        let thumbnailsContext = "\(revisionContext).Thumbnails"
        let thumbnailsDic: [JSONDictionary] = try obtain("Thumbnails", from: activeRevision, context: thumbnailsContext)
        var thumbnails: [PDClient.Thumbnail] = []
        for dic in thumbnailsDic {
            let thumbnail = PDClient.Thumbnail(
                thumbnailID: try obtain("ThumbnailID", from: dic, context: "\(thumbnailsContext).ThumbnailID"),
                type: try obtain("Type", from: dic, context: "\(thumbnailsContext).Type"),
                hash: try obtain("Hash", from: dic, context: "\(thumbnailsContext).Hash"),
                size: try obtain("EncryptedSize", from: dic, context: "\(thumbnailsContext).EncryptedSize")
            )
            thumbnails.append(thumbnail)
        }

        var photo: PDClient.Photo?
        if let photoDTO {
            let photoContext = "loadPhotoLinkDetailCall.responseBody.Photo"
            photo = PDClient.Photo(
                linkID: linkID,
                captureTime: try obtain("CaptureTime", from: photoDTO, context: "\(photoContext).CaptureTime"),
                addedTime: nil, // Don't have enough data from link details call
                mainPhotoLinkID: try obtainOptional("MainPhotoLinkID", from: photoDTO, context: "\(photoContext).MainPhotoLinkID"),
                relatedPhotosLinkIDs: try obtain("RelatedPhotosLinkIDs", from: photoDTO, context: "\(photoContext).RelatedPhotosLinkIDs"),
                hash: nameHash,
                contentHash: try obtain("ContentHash", from: photoDTO, context: "\(photoContext).ContentHash")
            )
        }

        let revisionShort = RevisionShort(
            ID: try obtain("RevisionID", from: activeRevision, context: "\(revisionContext).RevisionID"),
            createTime: try obtain("CreateTime", from: activeRevision, context: "\(revisionContext).CreateTime"),
            size: try obtain("EncryptedSize", from: activeRevision, context: "\(revisionContext).EncryptedSize"),
            manifestSignature: try obtain("ManifestSignature", from: activeRevision, context: "\(revisionContext).ManifestSignature"),
            signatureAddress: try obtainOptional("SignatureEmail", from: activeRevision, context: "\(revisionContext).SignatureEmail"),
            state: try NodeState(rawValue: nodeState) ?! "Invalid NodeState",
            thumbnail: thumbnails.count,
            thumbnails: thumbnails,
            photo: photo
        )
        return revisionShort
    }

    func parsePhotoLinkDetails(_ responseLink: JSONDictionary, volumeID: String) throws -> Link {
        let context = "loadPhotoLinkDetailCall.responseBody"
        let linkDTO: JSONDictionary = try obtain("Link", from: responseLink, context: "\(context).Link")
        let linkContext = "\(context).linkDTO"
        let fileContext = "\(context).File"
        let fileDTO: JSONDictionary? = try obtainOptional("File", from: responseLink, context: fileContext)
        let photoContext = "\(context).Photo"
        let photoDTO: JSONDictionary? = try obtainOptional("Photo", from: responseLink, context: photoContext)
        let dto = try (fileDTO ?? photoDTO) ?! "Doesn't have data properties"
        let dataContext = "\(context).dataDTO"

        let activeRevision: JSONDictionary = try obtain("ActiveRevision", from: dto, context: "\(dataContext).ActiveRevision")
        let linkID: String = try obtain("LinkID", from: linkDTO, context: "\(linkContext).LinkID")
        let nameHash: String = try obtain("NameHash", from: linkDTO, context: "\(linkContext).NameHash")
        let type: Int = try obtain("Type", from: linkDTO, context: "\(linkContext).Type")
        let state: Int = try obtain("State", from: linkDTO, context: "\(linkContext).State")

        let fileProperties = FileProperties(
            contentKeyPacket: try obtain("ContentKeyPacket", from: dto, context: "\(dataContext).ContentKeyPacket"),
            contentKeyPacketSignature: try obtain("ContentKeyPacketSignature", from: dto, context: "\(dataContext).ContentKeyPacketSignature"),
            activeRevision: try parsePhotoRevisionShort(from: activeRevision, nodeState: state, linkID: linkID, nameHash: nameHash, photoDTO: photoDTO)
        )

        var photoProperties: PhotoProperties?
        if let photoDTO {
            let albumsDTO: [JSONDictionary] = try obtain("Albums", from: photoDTO, context: "\(photoDTO).Albums")
            let albums = try albumsDTO.map { PhotoAlbum(albumLinkID: try obtain("AlbumLinkID", from: $0, context: "\(photoDTO).Albums.AlbumLinkID")) }
            let tags: [Int] = try obtain("Tags", from: photoDTO, context: "\(photoDTO).Tags")
            photoProperties = PhotoProperties(albums: albums, tags: tags)
        }
        let sharingDetails: SharingDetails? = getSharingDetails(from: responseLink, context: context)

        let link = Link(
            linkID: linkID,
            parentLinkID: try obtainOptional("ParentLinkID", from: linkDTO, context: "\(linkContext).ParentLinkID"),
            volumeID: volumeID,
            type: try LinkType(rawValue: type) ?! "Invalid link type",
            name: try obtain("Name", from: linkDTO, context: "\(linkContext).Name"),
            nameSignatureEmail: try obtainOptional("NameSignatureEmail", from: linkDTO, context: "\(linkContext).NameSignatureEmail"),
            hash: nameHash,
            state: try NodeState(rawValue: state) ?! "Invalid NodeState",
            expirationTime: nil,
            size: try obtain("TotalEncryptedSize", from: dto, context: dataContext),
            MIMEType: try obtain("MediaType", from: dto, context: dataContext),
            attributes: 1,
            permissions: 7,
            nodeKey: try obtain("NodeKey", from: linkDTO, context: "\(linkContext).NodeKey"),
            nodePassphrase: try obtain("NodePassphrase", from: linkDTO, context: "\(linkContext).NodePassphrase"),
            nodePassphraseSignature: try obtain("NodePassphraseSignature", from: linkDTO, context: "\(linkContext).NodePassphraseSignature"),
            signatureEmail: try obtain("SignatureEmail", from: linkDTO, context: "\(linkContext).SignatureEmail"),
            createTime: try obtain("CreateTime", from: linkDTO, context: "\(linkContext).CreateTime"),
            modifyTime: try obtain("ModifyTime", from: linkDTO, context: "\(linkContext).ModifyTime"),
            trashed: try obtainOptional("TrashTime", from: linkDTO, context: "\(linkContext).TrashTime"),
            sharingDetails: sharingDetails,
            nbUrls: 0,
            activeUrls: 0,
            urlsExpired: 0,
            XAttr: try obtainOptional("XAttr", from: activeRevision, context: "\(dataContext).ActiveRevision.XAttr"),
            fileProperties: fileProperties,
            folderProperties: nil,
            photoProperties: photoProperties
        )
        return link
    }
    
    // MARK: - File
    
    private func parseFileRevisionShort(
        from activeRevision: JSONDictionary,
        nodeState: Int,
        linkID: String,
        nameHash: String
    ) throws -> RevisionShort {
        let revisionContext = "loadFileLinkDetailCall.responseBody.dataDTO.ActiveRevision"
        let thumbnailsContext = "\(revisionContext).Thumbnails"
        let thumbnailsDic: [JSONDictionary] = try obtain("Thumbnails", from: activeRevision, context: thumbnailsContext)
        var thumbnails: [PDClient.Thumbnail] = []
        for dic in thumbnailsDic {
            let thumbnail = PDClient.Thumbnail(
                thumbnailID: try obtain("ThumbnailID", from: dic, context: "\(thumbnailsContext).ThumbnailID"),
                type: try obtain("Type", from: dic, context: "\(thumbnailsContext).Type"),
                hash: try obtain("Hash", from: dic, context: "\(thumbnailsContext).Hash"),
                size: try obtain("EncryptedSize", from: dic, context: "\(thumbnailsContext).EncryptedSize")
            )
            thumbnails.append(thumbnail)
        }

        var photo: PDClient.Photo?
        
        let photoDTO: JSONDictionary? = try obtainOptional("Photo", from: activeRevision, context: revisionContext)
        if let photoDTO {
            let photoContext = "loadFileLinkDetailCall.responseBody.Photo"
            photo = PDClient.Photo(
                linkID: linkID,
                captureTime: try obtain("CaptureTime", from: photoDTO, context: "\(photoContext).CaptureTime"),
                addedTime: nil, // Don't have enough data from link details call
                mainPhotoLinkID: try obtainOptional("MainPhotoLinkID", from: photoDTO, context: "\(photoContext).MainPhotoLinkID"),
                relatedPhotosLinkIDs: try obtain("RelatedPhotosLinkIDs", from: photoDTO, context: "\(photoContext).RelatedPhotosLinkIDs"),
                hash: nameHash,
                contentHash: try obtain("ContentHash", from: photoDTO, context: "\(photoContext).ContentHash")
            )
        }

        let revisionShort = RevisionShort(
            ID: try obtain("RevisionID", from: activeRevision, context: "\(revisionContext).RevisionID"),
            createTime: try obtain("CreateTime", from: activeRevision, context: "\(revisionContext).CreateTime"),
            size: try obtain("EncryptedSize", from: activeRevision, context: "\(revisionContext).EncryptedSize"),
            manifestSignature: try obtain("ManifestSignature", from: activeRevision, context: "\(revisionContext).ManifestSignature"),
            signatureAddress: try obtainOptional("SignatureEmail", from: activeRevision, context: "\(revisionContext).SignatureEmail"),
            state: try NodeState(rawValue: nodeState) ?! "Invalid NodeState",
            thumbnail: thumbnails.count,
            thumbnails: thumbnails,
            photo: photo
        )
        return revisionShort
    }

    func parseFileLinkDetails(_ responseLink: JSONDictionary, volumeID: String) throws -> Link {
        let context = "loadFileLinkDetailCall.responseBody"
        let linkDTO: JSONDictionary = try obtain("Link", from: responseLink, context: "\(context).Link")
        let linkContext = "\(context).linkDTO"
        let fileContext = "\(context).File"
        let fileDTO: JSONDictionary? = try obtainOptional("File", from: responseLink, context: fileContext)
        let photoContext = "\(context).Photo"
        let photoDTO: JSONDictionary? = try obtainOptional("Photo", from: responseLink, context: photoContext)
        let dto = try (fileDTO ?? photoDTO) ?! "Doesn't have data properties"
        let dataContext = "\(context).dataDTO"

        let activeRevision: JSONDictionary = try obtain("ActiveRevision", from: dto, context: "\(dataContext).ActiveRevision")
        let linkID: String = try obtain("LinkID", from: linkDTO, context: "\(linkContext).LinkID")
        let nameHash: String = try obtain("NameHash", from: linkDTO, context: "\(linkContext).NameHash")
        let type: Int = try obtain("Type", from: linkDTO, context: "\(linkContext).Type")
        let state: Int = try obtain("State", from: linkDTO, context: "\(linkContext).State")

        let fileProperties = FileProperties(
            contentKeyPacket: try obtain("ContentKeyPacket", from: dto, context: "\(dataContext).ContentKeyPacket"),
            contentKeyPacketSignature: try obtain("ContentKeyPacketSignature", from: dto, context: "\(dataContext).ContentKeyPacketSignature"),
            activeRevision: try parseFileRevisionShort(from: activeRevision, nodeState: state, linkID: linkID, nameHash: nameHash)
        )

        var photoProperties: PhotoProperties?
        if let photoDTO {
            let albumsDTO: [JSONDictionary] = try obtain("Albums", from: photoDTO, context: "\(photoDTO).Albums")
            let albums = try albumsDTO.map { PhotoAlbum(albumLinkID: try obtain("AlbumLinkID", from: $0, context: "\(photoDTO).Albums.AlbumLinkID")) }
            let tags: [Int] = try obtain("Tags", from: photoDTO, context: "\(photoDTO).Tags")
            photoProperties = PhotoProperties(albums: albums, tags: tags)
        }
        let sharingDetails: SharingDetails? = getSharingDetails(from: responseLink, context: context)

        let link = Link(
            linkID: linkID,
            parentLinkID: try obtainOptional("ParentLinkID", from: linkDTO, context: "\(linkContext).ParentLinkID"),
            volumeID: volumeID,
            type: try LinkType(rawValue: type) ?! "Invalid link type",
            name: try obtain("Name", from: linkDTO, context: "\(linkContext).Name"),
            nameSignatureEmail: try obtainOptional("NameSignatureEmail", from: linkDTO, context: "\(linkContext).NameSignatureEmail"),
            hash: nameHash,
            state: try NodeState(rawValue: state) ?! "Invalid NodeState",
            expirationTime: nil,
            size: try obtain("TotalEncryptedSize", from: dto, context: dataContext),
            MIMEType: try obtain("MediaType", from: dto, context: dataContext),
            attributes: 1,
            permissions: 7,
            nodeKey: try obtain("NodeKey", from: linkDTO, context: "\(linkContext).NodeKey"),
            nodePassphrase: try obtain("NodePassphrase", from: linkDTO, context: "\(linkContext).NodePassphrase"),
            nodePassphraseSignature: try obtain("NodePassphraseSignature", from: linkDTO, context: "\(linkContext).NodePassphraseSignature"),
            signatureEmail: try obtain("SignatureEmail", from: linkDTO, context: "\(linkContext).SignatureEmail"),
            createTime: try obtain("CreateTime", from: linkDTO, context: "\(linkContext).CreateTime"),
            modifyTime: try obtain("ModifyTime", from: linkDTO, context: "\(linkContext).ModifyTime"),
            trashed: try obtainOptional("TrashTime", from: linkDTO, context: "\(linkContext).TrashTime"),
            sharingDetails: sharingDetails,
            nbUrls: 0,
            activeUrls: 0,
            urlsExpired: 0,
            XAttr: try obtainOptional("XAttr", from: activeRevision, context: "\(dataContext).ActiveRevision.XAttr"),
            fileProperties: fileProperties,
            folderProperties: nil,
            photoProperties: photoProperties
        )
        return link
    }
}
