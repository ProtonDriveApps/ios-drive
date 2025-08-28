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

/// List Shares
/// - GET: /drive/shares
public struct ListSharesEndpoint: Endpoint {

    public var request: URLRequest

    public init(parameters: Parameters, service: APIService, credential: ClientCredential) {
        var queries: [URLQueryItem] = []
        if let addressId = parameters.addressId {
            queries.append(URLQueryItem(name: "AddressID", value: "\(addressId)"))
        }
        if let showAll = parameters.showAll {
            queries.append(URLQueryItem(name: "ShowAll", value: "\(showAll.rawValue)"))
        }
        if let type = parameters.shareType {
            queries.append(URLQueryItem(name: "ShareType", value: "\(type.rawValue)"))
        }

        let url = service.url(of: "/shares", queries: queries)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }

    public struct Parameters {
        let addressId: String?
        let shareType: ShareType?
        let showAll: ShowAll?

        public init(addressId: String? = nil, shareType: ShareType? = nil, showAll: Parameters.ShowAll? = nil) {
            self.addressId = addressId
            self.shareType = shareType
            self.showAll = showAll
        }

        public enum ShareType: Int {
            case main = 1
            case standard = 2
            case device = 3
            case photos = 4
        }

        public enum ShowAll: Int {
            case `default` = 0
            case disabled = 1
        }
    }
}

extension ListSharesEndpoint {
    public struct Response: Codable {
        public typealias Share = ShareListing

        public let shares: [Share]
        public let code: Int
    }
}

// MARK: - Share Listing

public struct ShareListing: Codable {
    public let shareID: String
    public let volumeID: String
    public let type: ´Type´
    public let state: State
    public let creator: String
    public let locked: Bool?
    public let createTime: Int?
    public let modifyTime: Int?
    public let linkID: String

    public enum ´Type´: Int, Codable {
        case main = 1
        case standard = 2
        case device = 3
        case photos = 4
    }

    public enum State: Int, Codable {
        case active = 1
        case deleted = 2
        case restored = 3
    }
}
