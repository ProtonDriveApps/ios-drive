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
    public init(
        state: UpdateRevisionParameters.State,
        blockList: [UpdateRevisionBlocks],
        manifestSignature: String,
        signatureAddress: String,
        extendedAttributes: String?
    ) {
        self.State = state
        self.BlockList = blockList
        self.ManifestSignature = manifestSignature
        self.SignatureAddress = signatureAddress
        self.XAttr = extendedAttributes
    }
    
    var State: State
    var BlockList: [UpdateRevisionBlocks]
    var ManifestSignature: String
    var SignatureAddress: String
    var XAttr: String?

    public enum State: Int, Codable {
        case draft = 0, active, inactive
    }
}

struct UpdateRevisionEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
    }
    
    var request: URLRequest
    
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
