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
import ProtonCoreNetworking

// MARK: - Models
public struct DriveUserSettingsResponse: Codable {
    public let userSettings: DriveUserSettingsSelection
    public let defaults: DriveUserSettingsDefaults
    public let code: Int

    public init(userSettings: DriveUserSettingsSelection, defaults: DriveUserSettingsDefaults, code: Int) {
        self.userSettings = userSettings
        self.defaults = defaults
        self.code = code
    }
}

public struct DriveUserSettingsSelection: Codable {
    public let layout: Int?
    public let sort: Int?
    public let revisionRetentionDays: Int?
    public let b2BPhotosEnabled: Bool?
    public let docsCommentsNotificationsEnabled: Bool?
    public let docsCommentsNotificationsIncludeDocumentName: Bool?
    public let photoTags: [Int]?

    public init(layout: Int?, sort: Int?, revisionRetentionDays: Int?, b2BPhotosEnabled: Bool?, docsCommentsNotificationsEnabled: Bool?, docsCommentsNotificationsIncludeDocumentName: Bool?, photoTags: [Int]?) {
        self.layout = layout
        self.sort = sort
        self.revisionRetentionDays = revisionRetentionDays
        self.b2BPhotosEnabled = b2BPhotosEnabled
        self.docsCommentsNotificationsEnabled = docsCommentsNotificationsEnabled
        self.docsCommentsNotificationsIncludeDocumentName = docsCommentsNotificationsIncludeDocumentName
        self.photoTags = photoTags
    }
}

public struct DriveUserSettingsDefaults: Codable {
    public let revisionRetentionDays: Int
    public let b2BPhotosEnabled: Bool
    public let docsCommentsNotificationsEnabled: Bool
    public let docsCommentsNotificationsIncludeDocumentName: Bool
    public let photoTags: [Int]

    public init(revisionRetentionDays: Int, b2BPhotosEnabled: Bool, docsCommentsNotificationsEnabled: Bool, docsCommentsNotificationsIncludeDocumentName: Bool, photoTags: [Int]) {
        self.revisionRetentionDays = revisionRetentionDays
        self.b2BPhotosEnabled = b2BPhotosEnabled
        self.docsCommentsNotificationsEnabled = docsCommentsNotificationsEnabled
        self.docsCommentsNotificationsIncludeDocumentName = docsCommentsNotificationsIncludeDocumentName
        self.photoTags = photoTags
    }
}

// MARK: - GetDriveUserSettingsEndpoint

/// Get User Settings
/// - GET: /drive/me/settings
struct GetDriveUserSettingsEndpoint: Endpoint {
    typealias Response = DriveUserSettingsResponse

    var request: URLRequest

    init(service: APIService, credential: ClientCredential) {
        // url
        let url = service.url(of: "/me/settings")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}
