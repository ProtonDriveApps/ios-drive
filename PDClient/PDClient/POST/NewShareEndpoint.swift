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

public struct NewShareShort: Codable {
    public let ID: String

    public init(ID: String) {
        self.ID = ID
    }
}

public struct NewShareParameters: Codable {
    let AddressID: String
    let Name: String
    let RootLinkID: String
    let ShareKey: String
    let SharePassphrase: String
    let SharePassphraseSignature: String
    let PassphraseKeyPacket: String
    let NameKeyPacket: String

    public init(
        addressID: String,
        name: String,
        rootLinkID: String,
        shareKey: String,
        sharePassphrase: String,
        sharePassphraseSignature: String,
        passphraseKeyPacket: String,
        nameKeyPacket: String
    ) {
        self.AddressID = addressID
        self.Name = name
        self.RootLinkID = rootLinkID
        self.ShareKey = shareKey
        self.SharePassphrase = sharePassphrase
        self.SharePassphraseSignature = sharePassphraseSignature
        self.PassphraseKeyPacket = passphraseKeyPacket
        self.NameKeyPacket = nameKeyPacket
    }
}

struct NewShareEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var share: NewShareShort
    }
    
    var request: URLRequest
    
    init(volumeID: Volume.VolumeID, parameters: NewShareParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/volumes")
        url.appendPathComponent(volumeID)
        url.appendPathComponent("/shares")
        
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
