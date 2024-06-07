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

public struct MoveEntryEndpoint: Endpoint {
    public struct Parameters: Codable {
        let Name: String
        let NodePassphrase: String
        let Hash: String
        let ParentLinkID: String
        let NameSignatureEmail: String
        let OriginalHash: String
        let NewShareID: String?

        public init(
            name: String,
            nodePassphrase: String,
            hash: String,
            parentLinkID: String,
            nameSignatureEmail: String,
            originalHash: String,
            newShareID: String?
        ) {
            self.Name = name
            self.NodePassphrase = nodePassphrase
            self.Hash = hash
            self.ParentLinkID = parentLinkID
            self.NameSignatureEmail = nameSignatureEmail
            self.OriginalHash = originalHash
            self.NewShareID = newShareID
        }
    }

    public struct Response: Codable {
        var code: Int
    }

    public var request: URLRequest

    public init(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: Parameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/links")
        url.appendPathComponent(nodeID)
        url.appendPathComponent("/move")

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
