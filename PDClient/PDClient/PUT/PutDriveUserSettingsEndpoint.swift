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

public struct DriveUserSettingsUpdateRequest: Codable {
    public let layout: Int?
    public let sort: Int?
    public let revisionRetentionDays: Int?
    public let b2BPhotosEnabled: Bool?
    public let docsCommentsNotificationsEnabled: Bool?
    public let docsCommentsNotificationsIncludeDocumentName: Bool?
    public let photoTags: [Int]?

    public init(
        layout: Int? = nil,
        sort: Int? = nil,
        revisionRetentionDays: Int? = nil,
        b2BPhotosEnabled: Bool? = nil,
        docsCommentsNotificationsEnabled: Bool? = nil,
        docsCommentsNotificationsIncludeDocumentName: Bool? = nil,
        photoTags: [Int]? = nil
    ) {
        self.layout = layout
        self.sort = sort
        self.revisionRetentionDays = revisionRetentionDays
        self.b2BPhotosEnabled = b2BPhotosEnabled
        self.docsCommentsNotificationsEnabled = docsCommentsNotificationsEnabled
        self.docsCommentsNotificationsIncludeDocumentName = docsCommentsNotificationsIncludeDocumentName
        self.photoTags = photoTags
    }
}

struct PutDriveUserSettingsEndpoint: Endpoint {
    typealias Response = DriveUserSettingsResponse

    var request: URLRequest

    init(
        service: APIService,
        credential: ClientCredential,
        settings: DriveUserSettingsUpdateRequest
    ) throws {
        // url
        let url = service.url(of: "/me/settings")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // body
        request.httpBody = try JSONEncoder(strategy: .capitalizeFirstLetter).encode(settings)

        self.request = request
    }
}
