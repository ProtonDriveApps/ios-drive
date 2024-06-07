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

public protocol EditShareURLParameters: Codable {
    var parameters: [String: Any]? { get }
}

public struct EditShareURLPasswordAndDuration: EditShareURLParameters {
    let ExpirationDuration: Int?
    let UrlPasswordSalt: String
    let SharePasswordSalt: String
    let SRPVerifier: String
    let SRPModulusID: String
    let Flags: ShareURLMeta.Flags
    let SharePassphraseKeyPacket: String
    let Password: String

    public private(set) var parameters: [String: Any]?

    public init(_ expirationParameters: EditShareURLExpiration, _ passwordParameters: EditShareURLPassword) {
        self.ExpirationDuration = expirationParameters.ExpirationDuration
        self.UrlPasswordSalt = passwordParameters.UrlPasswordSalt
        self.SharePasswordSalt = passwordParameters.SharePasswordSalt
        self.SRPVerifier = passwordParameters.SRPVerifier
        self.SRPModulusID = passwordParameters.SRPModulusID
        self.Flags = passwordParameters.Flags
        self.SharePassphraseKeyPacket = passwordParameters.SharePassphraseKeyPacket
        self.Password = passwordParameters.Password

        parameters = expirationParameters.parameters?.merging(passwordParameters.parameters ?? [:], uniquingKeysWith: { $1 })
    }

    public enum CodingKeys: String, CodingKey {
        case ExpirationDuration
        case UrlPasswordSalt
        case SharePasswordSalt
        case SRPVerifier
        case SRPModulusID
        case Flags
        case SharePassphraseKeyPacket
        case Password
    }
}

public struct EditShareURLPassword: EditShareURLParameters {
    let UrlPasswordSalt: String
    let SharePasswordSalt: String
    let SRPVerifier: String
    let SRPModulusID: String
    let Flags: ShareURLMeta.Flags
    let SharePassphraseKeyPacket: String
    let Password: String

    public init(urlPasswordSalt: String, sharePasswordSalt: String, srpVerifier: String, srpModulusID: String, flags: ShareURLMeta.Flags, sharePassphraseKeyPacket: String, encryptedUrlPassword: String) {
        self.UrlPasswordSalt = urlPasswordSalt
        self.SharePasswordSalt = sharePasswordSalt
        self.SRPVerifier = srpVerifier
        self.SRPModulusID = srpModulusID
        self.Flags = flags
        self.SharePassphraseKeyPacket = sharePassphraseKeyPacket
        self.Password = encryptedUrlPassword
    }

    public var parameters: [String: Any]? {
        guard let encoded = try? JSONEncoder().encode(self),
              let json = try? JSONSerialization.jsonObject(with: encoded, options: .fragmentsAllowed),
              let castedJSON = json as? [String: Any] else {
                  return nil
              }
        return castedJSON
    }
}

public struct EditShareURLExpiration: EditShareURLParameters {
    let ExpirationDuration: Int?

    public init(expirationDuration: Int?) {
        self.ExpirationDuration = expirationDuration
    }

    public var parameters: [String: Any]? {
        [
            "ExpirationDuration": ExpirationDuration as Any
        ]
    }
}

struct EditShareURLEndpoint<Parameters: EditShareURLParameters>: Endpoint {
    public struct Response: Codable {
        var code: Int
        var shareURL: ShareURLMeta
    }

    var request: URLRequest
    private var codableParameters: Parameters

    var parameters: [String: Any]? {
        codableParameters.parameters
    }
    
    init(shareURLID: ShareURLMeta.ID, shareID: Share.ShareID, parameters: Parameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/urls")
        url.appendPathComponent(shareURLID)

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let encoded = try? JSONEncoder().encode(parameters)
        request.httpBody = encoded

        self.request = request

        // Codable parameters
        self.codableParameters = parameters
    }
}
