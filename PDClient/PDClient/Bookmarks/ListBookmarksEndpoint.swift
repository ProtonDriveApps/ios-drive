// Copyright (c) 2024 Proton AG
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

// MARK: - Response Structure
public struct ListBookmarksResponse: Codable {
    public let bookmarks: [BookmarkResponse]
    public let code: Int

    public struct BookmarkResponse: Codable {
        public let encryptedUrlPassword: String
        public let createTime: Int
        public let token: TokenResponse

        public struct TokenResponse: Codable {
            public let token: String
            public let linkType: Int
            public let linkID: String
            public let sharePasswordSalt: String
            public let sharePassphrase: String
            public let shareKey: String
            public let nodePassphrase: String
            public let nodeKey: String
            public let name: String
            public let contentKeyPacket: String?
            public let MIMEType: String?
            public let permissions: Int
            public let size: Int?
            public let thumbnailURLInfo: ThumbnailURLInfoResponse?
            public let nodeHashKey: String?

            public struct ThumbnailURLInfoResponse: Codable {
                public let url: String?
                public let bareURL: String?
                public let token: String?
            }
        }
    }
}

// MARK: - Endpoint
/// Fetch the list of bookmarks
/// - GET: /drive/v2/bookmarks
public struct ListBookmarksEndpoint: Endpoint {
    public typealias Response = ListBookmarksResponse

    public let request: URLRequest

    public init(service: APIService, credential: ClientCredential) {
        let url = service.url(of: "/v2/shared-bookmarks")
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        self.request = request
    }
}
