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

public struct UpdateShareURLParameters: Codable {
    let ExpirationDuration: Int?
    let Flags: ShareURLMeta.Flags?
    let Password: String?
    let SharePassphraseKeyPacket: String?
    let SRPModulusID: String?
    let SRPVerifier: String?
    let UrlPasswordSalt: String?
    let SharePasswordSalt: String?

    public init(
        expirationDuration: TimeInterval?,
        customPassword: ShareUrlCustomPasswordInfo?
    ) {
        self.ExpirationDuration = expirationDuration.asInt
        self.Flags = customPassword?.flags
        self.Password = customPassword?.encryptedUrlPassword
        self.SharePassphraseKeyPacket = customPassword?.sharePassphraseKeyPacket
        self.SRPModulusID = customPassword?.srpModulusID
        self.SRPVerifier = customPassword?.srpVerifier
        self.UrlPasswordSalt = customPassword?.urlPasswordSalt
        self.SharePasswordSalt = customPassword?.sharePasswordSalt
    }
}

public struct ShareUrlCustomPasswordInfo {
    let urlPasswordSalt: String
    let sharePasswordSalt: String
    let srpVerifier: String
    let srpModulusID: String
    let flags: ShareURLMeta.Flags
    let sharePassphraseKeyPacket: String
    let encryptedUrlPassword: String

    public init(
        urlPasswordSalt: String,
        sharePasswordSalt: String,
        srpVerifier: String,
        srpModulusID: String,
        flags: ShareURLMeta.Flags,
        sharePassphraseKeyPacket: String,
        encryptedUrlPassword: String
    ) {
        self.urlPasswordSalt = urlPasswordSalt
        self.sharePasswordSalt = sharePasswordSalt
        self.srpVerifier = srpVerifier
        self.srpModulusID = srpModulusID
        self.flags = flags
        self.sharePassphraseKeyPacket = sharePassphraseKeyPacket
        self.encryptedUrlPassword = encryptedUrlPassword
    }
}

struct UpdateShareURLEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var shareURL: ShareURLMeta
    }

    var request: URLRequest

    init(id: ShareURLMeta.ID, shareID: Share.ShareID, parameters: UpdateShareURLParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/urls")
        url.appendPathComponent(id)

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
