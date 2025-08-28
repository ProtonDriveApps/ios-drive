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
import PDCore

final class BookmarkUrlConstructorInteractor: BookmarkUrlConstructorInteractorProtocol {
    private let baseOrigin: String
    private let dataSource: BookmarkPasswordDataSource

    init(dataSource: BookmarkPasswordDataSource, baseOrigin: String) {
        self.dataSource = dataSource
        self.baseOrigin = baseOrigin
    }

    func makeURL() async throws -> URL {
        let password = try await dataSource.getPassword()

        guard let baseOrigin = URL(string: baseOrigin),
              var urlComponents = URLComponents(url: baseOrigin, resolvingAgainstBaseURL: false),
              let host = urlComponents.host else {
            throw DriveError("Invalid baseOrigin or missing host")
        }

        if !host.hasPrefix(drivePrefix) {
            urlComponents.host = "drive." + host
        }
         urlComponents.path = "/urls/"

         guard let baseURL = urlComponents.url else {
             throw DriveError("Failed to construct base URL")
         }

         let completeURLString = baseURL.absoluteString + password

         guard let completeURL = URL(string: completeURLString) else {
             throw DriveError("Failed to construct final URL")
         }

         return completeURL
    }

    private var drivePrefix: String {
        "drive."
    }
}
