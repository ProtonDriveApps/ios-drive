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

/// photos/volumes/{volumeID}/links/{linkID}/revisions/{revisionID}/xattr
public struct UpdateXAttrEndpoint: Endpoint {
    public typealias Response = CodeResponse

    public var request: URLRequest

    public init(parameters: Parameters, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/photos/volumes")
        url.appendPathComponent(parameters.volumeID)
        url.appendPathComponent("links")
        url.appendPathComponent(parameters.linkID)
        url.appendPathComponent("revisions")
        url.appendPathComponent(parameters.revisionID)
        url.appendPathComponent("xattr")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let encoder = JSONEncoder(strategy: .capitalizeFirstLetter)
        request.httpBody = try? encoder.encode(parameters.body)

        self.request = request
    }
}

extension UpdateXAttrEndpoint {
    public struct Parameters {
        public var volumeID: String
        public var linkID: String
        public var revisionID: String
        public var body: Body

        public init(volumeID: String, linkID: String, revisionID: String, body: Body) {
            self.volumeID = volumeID
            self.linkID = linkID
            self.revisionID = revisionID
            self.body = body
        }
    }

    public struct Body: Codable {
        public var signatureEmail: String
        public var xAttr: String

        public init(signatureEmail: String, xAttr: String) {
            self.signatureEmail = signatureEmail
            self.xAttr = xAttr
        }
    }
}
