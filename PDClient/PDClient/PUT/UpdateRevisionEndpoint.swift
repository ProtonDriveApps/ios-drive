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

public struct UpdateRevisionBlocks: Codable {
    public init(index: Int, token: String) {
        self.Index = index
        self.Token = token
    }
    
    var Index: Int
    var Token: String
}

public struct UpdateRevisionParameters: Codable {
    public let ManifestSignature: String
    public let SignatureAddress: String
    public let XAttr: String?
    public let Photo: Photo?

    public init(
        manifestSignature: String,
        signatureAddress: String,
        extendedAttributes: String?,
        photo: Photo?
    ) {
        self.ManifestSignature = manifestSignature
        self.SignatureAddress = signatureAddress
        self.XAttr = extendedAttributes
        self.Photo = photo
    }

    public struct Photo: Codable {
        public let CaptureTime: Int
        public let MainPhotoLinkID: String?
        public let Exif: String?
        public let ContentHash: String
        public let Tags: [Int]

        public init(captureTime: Int, mainPhotoLinkID: String?, exif: String?, contentHash: String, tags: [Int] = []) {
            self.CaptureTime = captureTime
            self.MainPhotoLinkID = mainPhotoLinkID
            self.Exif = exif
            self.ContentHash = contentHash
            self.Tags = tags
        }
    }
}

public struct UpdateRevisionEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        
        public init(code: Int) {
            self.code = code
        }
    }
    
    public var request: URLRequest
    
    init(shareID: Share.ShareID, fileID: Link.LinkID, revisionID: Revision.RevisionID, parameters: UpdateRevisionParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/files")
        url.appendPathComponent(fileID)
        url.appendPathComponent("/revisions")
        url.appendPathComponent(revisionID)
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        request.httpBody = try? JSONEncoder().encode(parameters)
        
        self.request = request
    }
}
