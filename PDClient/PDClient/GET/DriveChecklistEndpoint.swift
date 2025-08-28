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

/// /checklist/get-started
/// Fetch the current storage bonus status
public struct DriveChecklistEndpoint: Endpoint {
    public struct Response: Codable {
        public let items: [String]
        public let createdAt: TimeInterval?
        public let expiresAt: TimeInterval?
        public let userWasRewarded: Bool
        public let seen: Bool
        public let completed: Bool
        public let rewardInGB: Int
        public let visible: Bool
        public let code: Int
    }

    public var request: URLRequest

    public init(service: APIService, credential: ClientCredential) {
        let url = service.url(of: "/v2/checklist/get-started")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}

public struct DriveChecklistStatusResponse: Codable, Equatable {
    public let items: [String]
    public let createdAt: Date
    public let expiresAt: Date
    public let userWasRewarded: Bool
    public let seen: Bool
    public let completed: Bool
    public let rewardInGB: Int
    public let visible: Bool

    public init(
        items: [String],
        createdAt: Date,
        expiresAt: Date,
        userWasRewarded: Bool,
        seen: Bool,
        completed: Bool,
        rewardInGB: Int,
        visible: Bool
    ) {
        self.items = items
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.userWasRewarded = userWasRewarded
        self.seen = seen
        self.completed = completed
        self.rewardInGB = rewardInGB
        self.visible = visible
    }

    public init(from response: DriveChecklistEndpoint.Response) {
        self.items = response.items
        self.createdAt = Date(timeIntervalSince1970: response.createdAt ?? .zero)
        self.expiresAt = Date(timeIntervalSince1970: response.expiresAt ?? .zero)
        self.userWasRewarded = response.userWasRewarded
        self.seen = response.seen
        self.completed = response.completed
        self.rewardInGB = response.rewardInGB
        self.visible = response.visible
    }
}
