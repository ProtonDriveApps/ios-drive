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

/// Transfer photos from and to albums
/// photos/volumes/{volumeID}/links/transfer-multiple
public struct TransferMultipleEndpoint: Endpoint {
    public struct Parameters: Codable {
        public let parentLinkID: String
        public let links: [MoveMultipleEndpoint.Link]
        public let nameSignatureEmail: String
        public let signatureEmail: String?

        public init(
            parentLinkID: String,
            links: [MoveMultipleEndpoint.Link],
            nameSignatureEmail: String,
            signatureEmail: String?
        ) {
            self.parentLinkID = parentLinkID
            self.links = links
            self.nameSignatureEmail = nameSignatureEmail
            self.signatureEmail = signatureEmail
        }
    }

    public struct Response: Codable {
        var code: Int

        public init(code: Int) {
            self.code = code
        }
    }

    public var request: URLRequest

    public init(volumeID: Volume.VolumeID, parameters: Parameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "photos/volumes")
        url.appendPathComponent(volumeID)
        url.appendPathComponent("/links")
        url.appendPathComponent("/transfer-multiple")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        request.httpBody = try? JSONEncoder(strategy: .capitalizeFirstLetter).encode(parameters)

        self.request = request
    }
}
