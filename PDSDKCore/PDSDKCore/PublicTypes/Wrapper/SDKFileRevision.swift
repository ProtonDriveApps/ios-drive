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
import ProtonDriveSDK
import PDCore

extension SDKFileRevision {
    public init(revision: CoreDataRevision) throws {
        let nodeUid = revision.file.genericIdentifierWithinManagedObjectContext.sdkUid
        // Uploading file doesn't have extended attributes

        // Temporary disable because iOS performance issue
        // Decrypting extended attributes for all files is slow and harms UX,
        // so we decrypt them on demand instead.
        // We can revert to using SDKFileRevision once we implement node enumeration and read data from SDK
        // related fields: claimedSize, sha1Data, claimedAdditionalMetadata

//        let extendedAttrs = try? revision.decryptedExtendedAttributes()
//        let claimedSize: Int64?
//        if let size = extendedAttrs?.common?.size {
//            claimedSize = Int64(size)
//        } else {
//            claimedSize = nil
//        }
//        let sha1Data: Data?
//        if let sha1 = extendedAttrs?.common?.digests?.sha1 {
//            sha1Data = Data(hex: sha1)
//        } else {
//            sha1Data = nil
//        }
//        let encoder = JSONEncoder.default
//        var metadata: [AdditionalMetadata] = []
//        if let location = extendedAttrs?.location {
//            let data = try encoder.encode(location)
//            metadata.append(AdditionalMetadata(name: location.fieldName, utf8JsonValue: data))
//        }
//
//        if let camera = extendedAttrs?.camera {
//            let data = try encoder.encode(camera)
//            metadata.append(AdditionalMetadata(name: camera.fieldName, utf8JsonValue: data))
//        }
//
//        if let media = extendedAttrs?.media {
//            let mediaData = try encoder.encode(media)
//            metadata.append(AdditionalMetadata(name: media.fieldName, utf8JsonValue: mediaData))
//        }
//
//        if let iOSPhotos = extendedAttrs?.iOSPhotos {
//            let iOSPhotosData = try encoder.encode(iOSPhotos)
//            metadata.append(AdditionalMetadata(name: iOSPhotos.fieldName, utf8JsonValue: iOSPhotosData))
//        }
        let state: RevisionState = revision.state == .active ? .active : .superseded
        self.init(
            uid: SDKRevisionUid(sdkNodeUid: nodeUid, revisionID: revision.id),
            state: state,
            creationTime: revision.created?.timeIntervalSince1970 ?? Date.distantPast.timeIntervalSince1970,
            storageSize: Int64(revision.size),
            claimedSize: nil,
            claimedDigests: FileContentDigests(
                sha1: nil,
                sha1Verified: revision.checksumVerified ?? false
            ),
            claimedModificationTime: nil, // CoreDataRevision doesn't have enough data
            thumbnails: revision.thumbnails.map { ThumbnailHeader(id: $0.id, type: Int($0.type.rawValue)) },
            claimedAdditionalMetadata: [],
            contentAuthor: SDKAuthor(emailAddress: revision.signatureAddress, signatureVerificationError: nil)
        )
    }

//    public func extendedAttributes() -> ExtendedAttributes {
//        var location: ExtendedAttributes.Location?
//        var camera: ExtendedAttributes.Camera?
//        var media: ExtendedAttributes.Media?
//        var iOSPhoto: ExtendedAttributes.iOSPhotos?
//        for metadata in self.claimedAdditionalMetadata ?? [] {
//            if metadata.name == "Location" {
//                location = try? JSONDecoder.default.decode(
//                    ExtendedAttributes.Location.self,
//                    from: metadata.utf8JsonValue
//                )
//            } else if metadata.name == "Camera" {
//                camera = try? JSONDecoder.default.decode(
//                    ExtendedAttributes.Camera.self,
//                    from: metadata.utf8JsonValue
//                )
//            } else if metadata.name == "Media" {
//                media = try? JSONDecoder.default.decode(
//                    ExtendedAttributes.Media.self,
//                    from: metadata.utf8JsonValue
//                )
//            } else if metadata.name == "iOS.photos" {
//                iOSPhoto = try? JSONDecoder.default.decode(
//                    ExtendedAttributes.iOSPhotos.self,
//                    from: metadata.utf8JsonValue
//                )
//            }
//        }
//        return ExtendedAttributes(
//            common: nil,
//            location: location,
//            camera: camera,
//            media: media,
//            iOSPhotos: iOSPhoto
//        )
//    }
}
