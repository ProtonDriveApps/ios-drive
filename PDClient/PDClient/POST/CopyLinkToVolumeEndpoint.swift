// Copyright (c) 2025 Proton AG
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

/// /drive/volumes/{volumeID}/links/{linkID}/copy
/// Copy a single file to a volume, providing the new parent link ID.
public struct CopyLinkToVolumeEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var linkID: String
    }

    public var request: URLRequest

    public init(parameters: Parameters, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/volumes")
        url.appendPathComponent(parameters.volumeID)
        url.appendPathComponent("/links")
        url.appendPathComponent(parameters.linkID)
        url.appendPathComponent("/copy")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        // body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .capitalizeFirstLetter
        request.httpBody = try? encoder.encode(parameters.body)

        self.request = request
    }
}

extension CopyLinkToVolumeEndpoint {
    public struct Parameters {
        public let volumeID: Volume.VolumeID
        public let linkID: Link.LinkID
        public let body: Body

        public init(volumeID: Volume.VolumeID, linkID: Link.LinkID, body: Body) {
            self.volumeID = volumeID
            self.linkID = linkID
            self.body = body
        }
    }

    public struct Body: Codable {
        public let name: String
        public let nodePassphrase: String
        public let hash: String
        public let targetVolumeID: Volume.VolumeID
        public let targetParentLinkID: Link.LinkID
        public let nameSignatureEmail: String
        /// Required when moving an anonymous Link.
        public let nodePassphraseSignature: String?
        public let signatureEmail: String?
        /// Optional, except when moving a Photo-Link.
        public let photos: Photos?

        public init(
            name: String,
            nodePassphrase: String,
            hash: String,
            targetVolumeID: Volume.VolumeID,
            targetParentLinkID: Link.LinkID,
            nameSignatureEmail: String,
            nodePassphraseSignature: String?,
            signatureEmail: String?,
            photos: Photos?
        ) {
            self.name = name
            self.nodePassphrase = nodePassphrase
            self.hash = hash
            self.targetVolumeID = targetVolumeID
            self.targetParentLinkID = targetParentLinkID
            self.nameSignatureEmail = nameSignatureEmail
            self.nodePassphraseSignature = nodePassphraseSignature
            self.signatureEmail = signatureEmail
            self.photos = photos
        }
    }

    public struct Photos: Codable {
        public let contentHash: String
        public let relatedPhotos: [RelatedPhoto]

        public init(contentHash: String, relatedPhotos: [RelatedPhoto]) {
            self.contentHash = contentHash
            self.relatedPhotos = relatedPhotos
        }
    }

    public struct RelatedPhoto: Codable {
        public let linkID: String
        public let name: String
        public let nodePassphrase: String
        public let hash: String
        public let contentHash: String

        public init(linkID: String, name: String, nodePassphrase: String, hash: String, contentHash: String) {
            self.linkID = linkID
            self.name = name
            self.nodePassphrase = nodePassphrase
            self.hash = hash
            self.contentHash = contentHash
        }
    }
}
