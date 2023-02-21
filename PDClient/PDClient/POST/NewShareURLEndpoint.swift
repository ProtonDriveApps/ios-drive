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

public struct NewShareURLParameters: Codable {
    public init(
        expirationTime: TimeInterval?,
        expirationDuration: TimeInterval?,
        maxAccesses: Int,
        creatorEmail: String,
        permissions: ShareURLMeta.Permissions,
        URLPasswordSalt: String,
        sharePasswordSalt: String,
        SRPVerifier: String,
        SRPModulusID: String,
        flags: ShareURLMeta.Flags,
        sharePassphraseKeyPacket: String,
        password: String,
        name: String? = nil
    ) {
        self.ExpirationTime = expirationTime.asInt
        self.ExpirationDuration = expirationDuration.asInt
        self.MaxAccesses = maxAccesses
        self.CreatorEmail = creatorEmail
        self.Permissions = permissions
        self.UrlPasswordSalt = URLPasswordSalt
        self.SharePasswordSalt = sharePasswordSalt
        self.SRPVerifier = SRPVerifier
        self.SRPModulusID = SRPModulusID
        self.Flags = flags
        self.SharePassphraseKeyPacket = sharePassphraseKeyPacket
        self.Password = password
    }
    
    var ExpirationTime: Int?
    var ExpirationDuration: Int?
    var MaxAccesses: Int
    var CreatorEmail: String
    var Permissions: ShareURLMeta.Permissions
    var UrlPasswordSalt: String
    var SharePasswordSalt: String
    var SRPVerifier: String
    var SRPModulusID: String
    var Flags: ShareURLMeta.Flags
    var SharePassphraseKeyPacket: String
    var Password: String
}

struct NewShareURLEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var shareURL: ShareURLMeta
    }
    
    var request: URLRequest
    
    init(shareID: Share.ShareID, parameters: NewShareURLParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/urls")
        
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

extension Optional where Wrapped == Double {
    var asInt: Int? {
        guard let wrapped = self else {
            return nil
        }
        return Int(wrapped)
    }
}
