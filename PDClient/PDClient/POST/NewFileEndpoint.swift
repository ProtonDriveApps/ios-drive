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

public struct NewFile: Codable {
    public var ID: String
    public var revisionID: String
}

public struct NewFileParameters: Codable {
    public init(name: String,
                hash: String,
                parentLinkID: String,
                nodeKey: String,
                nodePassphrase: String,
                nodePassphraseSignature: String,
                signatureAddress: String,
                contentKeyPacket: String,
                contentKeyPacketSignature: String,
                mimeType: String,
                clientUID: String)
    {
        self.Name = name
        self.Hash = hash
        self.ParentLinkID = parentLinkID
        self.NodeKey = nodeKey
        self.NodePassphrase = nodePassphrase
        self.NodePassphraseSignature = nodePassphraseSignature
        self.SignatureAddress = signatureAddress
        self.ContentKeyPacket = contentKeyPacket
        self.ContentKeyPacketSignature = contentKeyPacketSignature
        self.MIMEType = mimeType
        self.ClientUID = clientUID
    }

    var Name: String
    var Hash: String
    var ParentLinkID: String
    var NodeKey: String
    var NodePassphrase: String
    var NodePassphraseSignature: String
    var SignatureAddress: String
    var ContentKeyPacket: String
    var ContentKeyPacketSignature: String
    var MIMEType: String
    var ClientUID: String
}

struct NewFileEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var file: NewFile
    }
    
    var request: URLRequest
    
    init(shareID: Share.ShareID, parameters: NewFileParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/files")
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        request.httpBody = try? JSONEncoder().encode(parameters)
        
        self.request = request
    }
}
