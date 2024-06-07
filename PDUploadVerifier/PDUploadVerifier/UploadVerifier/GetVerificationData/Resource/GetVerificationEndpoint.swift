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
import PDClient
import ProtonCoreNetworking

public struct GetVerificationDataParameters {
    public let shareId: String
    public let linkId: String
    public let revisionId: String

    public init(shareId: String, linkId: String, revisionId: String) {
        self.shareId = shareId
        self.linkId = linkId
        self.revisionId = revisionId
    }
}

public struct GetVerificationDataResponse: Codable {
    public let verificationCode: String
    public let contentKeyPacket: String
    public let code: Int
}

/// Get verification data.
/// - GET: drive/shares/{enc_shareID}/links/{enc_linkID}/revisions/{enc_revisionID}/verification
public struct GetVerificationEndpoint: Endpoint {
    public typealias Response = GetVerificationDataResponse

    public let request: URLRequest

    public init(service: APIService, credential: ClientCredential, parameters: GetVerificationDataParameters) {
        let url = service.url(of: "/shares/\(parameters.shareId)/links/\(parameters.linkId)/revisions/\(parameters.revisionId)/verification")

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}
