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

import ProtonCoreNetworking
import Foundation

public struct BugReport {
    public let os: String
    public let osVersion: String
    public let client: String
    public let clientType: Int
    public let clientVersion: String
    public let title: String
    public let description: String
    public let username: String
    public let email: String
    public let files: [URL]

    public init(os: String, osVersion: String, client: String, clientType: Int, clientVersion: String, title: String, description: String, username: String, email: String, files: [URL]) {
        self.os = os
        self.osVersion = osVersion
        self.client = client
        self.clientType = clientType
        self.clientVersion = clientVersion
        self.title = title
        self.description = description
        self.username = username
        self.email = email
        self.files = files
    }
}

public final class ReportsBugsEndpoint: Request {
    public let report: BugReport

    public init( _ report: BugReport) {
        self.report = report
    }

    public var path: String {
        return "/core/v4/reports/bug"
    }

    public var method: HTTPMethod {
        return .post
    }

    public var parameters: [String: Any]? {
        return [
            "OS": report.os,
            "OSVersion": report.osVersion,
            "Client": report.client,
            "ClientVersion": report.clientVersion,
            "ClientType": String(report.clientType),
            "Title": report.title,
            "Description": report.description,
            "Username": report.username,
            "Email": report.email,
        ]
    }

    public var retryPolicy: ProtonRetryPolicy.RetryMode {
        .userInitiated
    }
}
